using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Search;

public sealed record SearchOptions
{
    /// <summary>
    /// Prune branches that cannot reach the top K of any strategy. Only active when every requested strategy is
    /// WeightedSum (a knee strategy needs the whole front). Never changes the best plans, only the work done.
    /// </summary>
    public bool BoundPruning { get; init; } = true;

    public int MaxDegreeOfParallelism { get; init; } = -1;
}

public sealed record SearchOutcome(
    IReadOnlyList<PlanCandidate> Front,
    IReadOnlyDictionary<StrategyId, IReadOnlyList<PlanCandidate>> TopK,
    SearchStats Stats);

public sealed class RotationSearch
{
    private const double Epsilon = 1e-9;

    private readonly SimEnvironment _env;
    private readonly SimState _start;
    private readonly IReadOnlyList<SeqEntry> _history;
    private readonly int _firstYear;
    private readonly Crop[] _crops;
    private readonly Strategy[] _strategies;
    private readonly SearchOptions _options;
    private readonly HashSet<CropId> _excluded;

    private readonly IReadOnlyList<Objective> _axes = ObjectiveScorer.Scored;
    private readonly int _minL, _maxL;
    private readonly double _floorMin;
    private readonly double[][] _weights;
    private readonly PlanSeason[] _seasonOf;
    private readonly bool[][] _groupMatch;
    private readonly double[] _upperBound;
    private readonly double _maxUpperBound;
    private readonly bool _boundPruning;
    private readonly int _survivalAxis;

    public RotationSearch(
        SimEnvironment env, SimState start, IReadOnlyList<SeqEntry> history, int firstHarvestYear,
        IEnumerable<Crop> candidates, IEnumerable<Strategy> strategies, SearchOptions? options = null)
    {
        _env = env;
        _start = start;
        _history = history;
        _firstYear = firstHarvestYear;
        _options = options ?? new SearchOptions();
        _crops = candidates.OrderBy(c => c.Id.Value, StringComparer.Ordinal).ToArray();
        _strategies = strategies.OrderBy(s => s.Id.Value, StringComparer.Ordinal).ToArray();
        _excluded = env.Farmer.ExcludedCrops.ToHashSet();

        if (_strategies.Length == 0)
            throw new ArgumentException("At least one strategy is needed.", nameof(strategies));

        _minL = _strategies.Min(s => s.MinCycleYears);
        _maxL = _strategies.Max(s => s.MaxCycleYears);
        _floorMin = _strategies.Min(s => s.SurvivalFloor);
        _weights = _strategies.Select(s => StrategySelector.Weights(s, _axes)).ToArray();
        _survivalAxis = _axes.ToList().IndexOf(Objective.Survival);
        _seasonOf = _crops.Select(c => new PlanSeason { MainCrop = c.Id }).ToArray();

        var shares = env.Settings.Constraints.GroupShares;
        _groupMatch = _crops.Select(c => shares.Select(g => g.Selector.Matches(c)).ToArray()).ToArray();

        // Rigorous per-crop ceiling on (survival CVaR x yield): static CVaR plus every positive survival override
        // that could apply to the crop, capped at 1. Yield and penalties can only lower it.
        _upperBound = _crops.Select(c =>
        {
            var boost = env.Kb.Interactions
                .Where(i => i.Target == ResponseTarget.Survival && i.Delta > 0 && i.Next.Matches(c))
                .Sum(i => i.Delta);
            return Math.Min(1.0, env.Survival![c.Id].Cvar + boost);
        }).ToArray();
        _maxUpperBound = _upperBound.Length == 0 ? 1.0 : _upperBound.Max();
        _boundPruning = _options.BoundPruning && _strategies.All(s => s.Mode == SelectionMode.WeightedSum);
    }

    public SearchOutcome Run(CancellationToken ct = default)
    {
        var tasks = BuildTasks();
        var results = new LocalResult[tasks.Count];

        Parallel.For(0, tasks.Count,
            new ParallelOptions { MaxDegreeOfParallelism = _options.MaxDegreeOfParallelism, CancellationToken = ct },
            i => results[i] = new Worker(this, tasks[i], ct).Run());

        // Merge in task order: the result cannot depend on which thread finished first.
        var front = new ParetoArchive();
        var topK = _strategies.Select(_ => new TopKList(_env.Settings.Search.TopKPerStrategy)).ToArray();
        var stats = SearchStats.Zero;

        foreach (var r in results)
        {
            foreach (var m in r.Archive.Members) front.TryAdd(m);
            for (var s = 0; s < _strategies.Length; s++)
                foreach (var (score, candidate) in r.TopK[s].Entries)
                    topK[s].Insert(score, candidate);
            stats += r.Stats;
        }

        return new SearchOutcome(
            front.Members.OrderBy(c => c.Key, StringComparer.Ordinal).ToList(),
            _strategies.Select((s, i) => (s.Id, (IReadOnlyList<PlanCandidate>)topK[i].Entries.Select(e => e.Candidate).ToList()))
                .ToDictionary(x => x.Id, x => x.Item2),
            stats);
    }

    /// <summary>
    /// One slice of the search: a fixed transition and cycle length and the crops of its first seasons (the
    /// "prefix"). Slicing a few levels deep keeps the parallel tasks small and even; with one level the first crops
    /// would own most of the work (canonical rotations only allow later crops after them).
    /// </summary>
    private readonly record struct SearchTask(int TransitionLength, int CycleLength, int[] Prefix);

    private List<SearchTask> BuildTasks()
    {
        var tasks = new List<SearchTask>();
        var n = _crops.Length;
        for (var t = 0; t <= _env.Settings.Search.MaxTransitionYears; t++)
            for (var l = _minL; l <= _maxL; l++)
            {
                var total = t + l;
                if (t == 1)
                {
                    for (var start = 0; start < n; start++)
                        foreach (var bridge in BridgesFor(start))
                        {
                            if (total < 3) { tasks.Add(new SearchTask(t, l, [bridge, start])); continue; }
                            for (var third = 0; third < n; third++)
                                tasks.Add(new SearchTask(t, l, [bridge, start, third]));
                        }
                    continue;
                }

                for (var first = 0; first < n; first++)
                {
                    if (total < 2) { tasks.Add(new SearchTask(t, l, [first])); continue; }
                    for (var second = 0; second < n; second++)
                        tasks.Add(new SearchTask(t, l, [first, second]));
                }
            }
        return tasks;
    }

    /// <summary>
    /// Bridge crops for a cycle that starts with crop <paramref name="start"/>: empty if the start is allowed right
    /// after the history (no bridge needed). Otherwise the crops that are allowed after the history and let the start
    /// follow, safest (highest static survival) first, at most <c>bridgeCropsPerStart</c> of them.
    /// </summary>
    private IEnumerable<int> BridgesFor(int start)
    {
        var settings = _env.Settings;
        var startCrop = _crops[start];

        var seq = _history.ToList();
        seq.Add(new SeqEntry(startCrop, _firstYear));
        if (ConstraintChecker.CheckAppend(seq, settings, _excluded) is null)
            return [];

        var legal = new List<int>();
        for (var b = 0; b < _crops.Length; b++)
        {
            seq = _history.ToList();
            seq.Add(new SeqEntry(_crops[b], _firstYear));
            if (ConstraintChecker.CheckAppend(seq, settings, _excluded) is not null) continue;
            seq.Add(new SeqEntry(startCrop, _firstYear + 1));
            if (ConstraintChecker.CheckAppend(seq, settings, _excluded) is null)
                legal.Add(b);
        }

        return legal
            .OrderByDescending(b => _env.Survival![_crops[b].Id].Cvar)
            .ThenBy(b => b)
            .Take(settings.Search.BridgeCropsPerStart);
    }

    private sealed class LocalResult(ParetoArchive archive, TopKList[] topK, SearchStats stats)
    {
        public ParetoArchive Archive { get; } = archive;
        public TopKList[] TopK { get; } = topK;
        public SearchStats Stats { get; } = stats;
    }

    private sealed class Worker
    {
        private readonly RotationSearch _s;
        private readonly SearchTask _task;
        private readonly CancellationToken _ct;
        private readonly int _t, _l, _total;
        private readonly bool _canonical;

        private readonly List<SeqEntry> _seq;
        private readonly List<SimulatedSeason> _seasons = [];
        private readonly int[] _path;
        private readonly double[] _ubPath;
        private readonly int[] _groupCount;
        private readonly int[] _groupLimit;

        private readonly ParetoArchive _archive = new();
        private readonly TopKList[] _topK;
        private long _nodes, _leaves, _scored, _prunedConstraint, _prunedSurvival, _prunedBound, _duplicates;

        public Worker(RotationSearch search, SearchTask task, CancellationToken ct)
        {
            _s = search;
            _task = task;
            _ct = ct;
            _t = task.TransitionLength;
            _l = task.CycleLength;
            _total = _t + _l;
            // Rotations of one cycle are the same plan only when nothing before or inside it distinguishes the start.
            _canonical = search._history.Count == 0 && _t == 0;

            _seq = [.. search._history];
            _path = new int[_total];
            _ubPath = new double[_l];
            var shares = search._env.Settings.Constraints.GroupShares;
            _groupCount = new int[shares.Count];
            _groupLimit = shares.Select(g => ConstraintChecker.GroupLimit(g.MaxShare, _l)).ToArray();
            _topK = search._strategies.Select(_ => new TopKList(search._env.Settings.Search.TopKPerStrategy)).ToArray();
        }

        public LocalResult Run()
        {
            Dfs(0, _s._start);
            return new LocalResult(_archive, _topK,
                new SearchStats(_nodes, _leaves, _scored, _prunedConstraint, _prunedSurvival, _prunedBound, _duplicates));
        }

        private void Dfs(int depth, SimState state)
        {
            if (depth == _total)
            {
                Close(state);
                return;
            }

            var isCycle = depth >= _t;
            var cyclePos = depth - _t;
            var year = _s._firstYear + depth;
            var fixedCrop = depth < _task.Prefix.Length ? _task.Prefix[depth] : -1;
            var from = fixedCrop >= 0 ? fixedCrop : 0;
            var to = fixedCrop >= 0 ? fixedCrop : _s._crops.Length - 1;

            for (var ci = from; ci <= to; ci++)
            {
                if ((++_nodes & 0xFFF) == 0) _ct.ThrowIfCancellationRequested();

                if (_canonical && isCycle && cyclePos > 0 && ci < _path[0])
                    continue;                       // the first crop of a canonical cycle is its smallest

                if (isCycle && !GroupAllows(ci))
                {
                    _prunedConstraint++;
                    continue;
                }

                var crop = _s._crops[ci];

                // A transition season is only a bridge: it is worth planning only when the cycle could not have
                // started one season earlier. Otherwise it is the same plan delayed by a year.
                if (_t > 0 && depth == _t && EntersOneSeasonEarlier(crop, year))
                {
                    _duplicates++;
                    continue;
                }

                _seq.Add(new SeqEntry(crop, year));
                if (ConstraintChecker.CheckAppend(_seq, _s._env.Settings, _s._excluded) is not null)
                {
                    _seq.RemoveAt(_seq.Count - 1);
                    _prunedConstraint++;
                    continue;
                }

                var step = SeasonSimulator.Step(state, new SeasonContext
                {
                    SeasonIndex = depth, HarvestYear = year, Season = _s._seasonOf[ci], Env = _s._env, CollectReasons = false
                });
                if (step.Evaluation.SurvivalCvar20 < _s._floorMin - Epsilon)
                {
                    _seq.RemoveAt(_seq.Count - 1);
                    _prunedSurvival++;
                    continue;
                }

                _path[depth] = ci;
                _seasons.Add(new SimulatedSeason(depth, year, !isCycle, _s._seasonOf[ci], step));
                if (isCycle)
                {
                    AddGroup(ci, +1);
                    _ubPath[cyclePos] = _s._upperBound[ci];
                }

                if (CanBePruned(isCycle ? cyclePos + 1 : 0))
                    _prunedBound++;
                else
                    Dfs(depth + 1, step.Next);

                if (isCycle) AddGroup(ci, -1);
                _seasons.RemoveAt(_seasons.Count - 1);
                _seq.RemoveAt(_seq.Count - 1);
            }
        }

        /// <summary>
        /// Branch and bound. The best this branch can still reach on survival is the sum of the chosen crops' ceilings
        /// plus the best ceiling for every position left; every other objective is at most 1. If that cannot beat the
        /// K-th best plan of any strategy that accepts this cycle length, nothing below can enter a top-K list.
        /// </summary>
        private bool CanBePruned(int cycleSeasonsChosen)
        {
            if (!_s._boundPruning) return false;

            var ceiling = _s._maxUpperBound * (_l - cycleSeasonsChosen);
            for (var i = 0; i < cycleSeasonsChosen; i++) ceiling += _ubPath[i];
            var survivalCeiling = ceiling / _l;

            for (var k = 0; k < _s._strategies.Length; k++)
            {
                var strategy = _s._strategies[k];
                if (_l < strategy.MinCycleYears || _l > strategy.MaxCycleYears) continue;

                var threshold = _topK[k].Threshold;
                if (threshold is null) return false;

                var w = _s._weights[k][_s._survivalAxis];
                var bound = w * survivalCeiling + (1 - w);
                if (bound >= threshold.Value - Epsilon) return false;
            }
            return true;
        }

        private bool EntersOneSeasonEarlier(Crop crop, int year)
        {
            var lastTransition = _seq[^1];
            _seq.RemoveAt(_seq.Count - 1);
            _seq.Add(new SeqEntry(crop, year - 1));
            var allowed = ConstraintChecker.CheckAppend(_seq, _s._env.Settings, _s._excluded) is null;
            _seq.RemoveAt(_seq.Count - 1);
            _seq.Add(lastTransition);
            return allowed;
        }

        private bool GroupAllows(int ci)
        {
            var match = _s._groupMatch[ci];
            for (var g = 0; g < match.Length; g++)
                if (match[g] && _groupCount[g] + 1 > _groupLimit[g]) return false;
            return true;
        }

        private void AddGroup(int ci, int delta)
        {
            var match = _s._groupMatch[ci];
            for (var g = 0; g < match.Length; g++)
                if (match[g]) _groupCount[g] += delta;
        }

        private void Close(SimState state)
        {
            _leaves++;
            if (_canonical && !IsSmallestRotation())
            {
                _duplicates++;
                return;
            }

            var repetitions = _s._env.Settings.Search.UnrollCycles;
            var wrapSeasons = (repetitions - 1) * _l;

            // First the wrap-around against the hard rules: it costs nothing, and a violation saves the simulation.
            var addedSeq = 0;
            var rulesHold = true;
            for (var k = 0; k < wrapSeasons && rulesHold; k++)
            {
                _seq.Add(new SeqEntry(_s._crops[_path[_t + k % _l]], _s._firstYear + _total + k));
                addedSeq++;
                rulesHold = ConstraintChecker.CheckAppend(_seq, _s._env.Settings, _s._excluded) is null;
            }

            var addedSeasons = 0;
            var ok = rulesHold;
            if (!rulesHold)
                _prunedConstraint++;

            var current = state;
            for (var k = 0; k < wrapSeasons && ok; k++)
            {
                var ci = _path[_t + k % _l];
                var depth = _total + k;
                var year = _s._firstYear + depth;

                var step = SeasonSimulator.Step(current, new SeasonContext
                {
                    SeasonIndex = depth, HarvestYear = year, Season = _s._seasonOf[ci], Env = _s._env, CollectReasons = false
                });
                _seasons.Add(new SimulatedSeason(depth, year, false, _s._seasonOf[ci], step));
                addedSeasons++;
                current = step.Next;

                if (step.Evaluation.SurvivalCvar20 < _s._floorMin - Epsilon)
                {
                    _prunedSurvival++;
                    ok = false;
                }
            }

            if (ok)
                Admit();

            _seq.RemoveRange(_seq.Count - addedSeq, addedSeq);
            _seasons.RemoveRange(_seasons.Count - addedSeasons, addedSeasons);
        }

        private void Admit()
        {
            _scored++;
            var lastCycleStart = _t + (_s._env.Settings.Search.UnrollCycles - 1) * _l;
            var vector = new double[_s._axes.Count];
            var worstCvar = ObjectiveScorer.ScoreFast(_seasons, lastCycleStart, _s._env, vector);

            // Most plans are beaten by something already kept. Find out before building any objects for them.
            var enters = _archive.Accepts(vector);
            var strategies = _s._strategies;
            Span<bool> intoTop = stackalloc bool[strategies.Length];
            var anyTop = false;
            for (var k = 0; k < strategies.Length; k++)
            {
                if (!StrategySelector.IsEligible(strategies[k], _l, worstCvar)) continue;
                var score = StrategySelector.WeightedScore(_s._weights[k], vector);
                intoTop[k] = _topK[k].Threshold is not { } threshold || score >= threshold;
                anyTop |= intoTop[k];
            }
            if (!enters && !anyTop) return;

            var plan = new RotationPlan
            {
                FirstHarvestYear = _s._firstYear,
                Transition = Enumerable.Range(0, _t).Select(i => _s._seasonOf[_path[i]]).ToList(),
                Cycle = Enumerable.Range(0, _l).Select(i => _s._seasonOf[_path[_t + i]]).ToList()
            };
            var candidate = PlanCandidate.FromVector(plan, vector, worstCvar);

            if (enters) _archive.TryAdd(candidate);
            for (var k = 0; k < strategies.Length; k++)
            {
                if (intoTop[k])
                    _topK[k].Insert(StrategySelector.WeightedScore(_s._weights[k], vector), candidate);
            }
        }

        /// <summary>True when no rotation of the cycle is lexicographically smaller (crop order is ordinal by id).</summary>
        private bool IsSmallestRotation()
        {
            for (var shift = 1; shift < _l; shift++)
            {
                for (var i = 0; i < _l; i++)
                {
                    var a = _path[_t + (i + shift) % _l];
                    var b = _path[_t + i];
                    if (a < b) return false;
                    if (a > b) break;
                }
            }
            return true;
        }
    }
}

public sealed class TopKList(int capacity)
{
    private readonly List<(double Score, PlanCandidate Candidate)> _entries = [];

    public IReadOnlyList<(double Score, PlanCandidate Candidate)> Entries => _entries;

    public double? Threshold => _entries.Count >= capacity ? _entries[^1].Score : null;

    public void Insert(double score, PlanCandidate candidate)
    {
        var index = _entries.Count;
        while (index > 0 && Better(score, candidate, _entries[index - 1]))
            index--;

        if (index >= capacity) return;
        _entries.Insert(index, (score, candidate));
        if (_entries.Count > capacity)
            _entries.RemoveAt(_entries.Count - 1);
    }

    private static bool Better(double score, PlanCandidate candidate, (double Score, PlanCandidate Candidate) other) =>
        score > other.Score || (score == other.Score && string.CompareOrdinal(candidate.Key, other.Candidate.Key) < 0);
}
