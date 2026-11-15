# REVIEW – nakładki mapy (`feat/map-overlays`)

Przegląd jak cudzego PR-a, co 3 iteracje. Priorytety: **W** wysoki (blokuje koniec), **Ś** średni, **N** niski.
Status: ✅ naprawione, ⏳ otwarte, 📝 do decyzji człowieka.

## Recenzja #1 (po iteracjach 1–2: model, parser gleby, repozytorium, kontroler)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 1 | Ś | ✅ | `overlay_controller.dart` | Każdy błąd HTTP (np. 502 „NASA niedostępna”) był traktowany jak brak internetu – użytkownik dostałby radę „sprawdź internet”, choć wina jest po stronie serwera. Dodany `OverlayError.server` dla `ApiException` + test. |
| 2 | Ś | ✅ | `overlay_controller.dart` | `catch (_)` w parsowaniu i ładowaniu połykał błędy bez śladu – błąd w parserze wyglądałby jak „złe dane z serwera”. Dodany `debugPrint` z id nakładki i błędem. |
| 3 | N | ✅ | `map_overlay.dart` | Komentarz obiecywał, że `id` służy do „zapamiętania wyboru” – nic takiego nie istnieje. Poprawiony. |
| 4 | N | ✅ | `map_layers_repository.dart` | `cacheKey` był publiczny bez potrzeby. Teraz prywatny. |
| 5 | Ś | ✅ (P5) | `api/api_client.dart` | Limit czasu `ApiClient` to 15 s, a pierwsze zapytanie o nowe miejsce trwa 5–10 s (NASA POWER + SoilGrids; u mnie 6,2 s). Przy wolnym NASA klient przerwie, a backend anuluje swoje zapytanie (`CancellationToken`), więc „Spróbuj ponownie” zaczyna od zera. Rozważyć dłuższy limit dla tego endpointu (np. parametr `timeout` w `getJson`). Nie zmieniałem – `lib/api/` poza zakresem. |
| 6 | N | ⏳ | `overlay_controller.dart` | Pusta lista `overlays` kończy się `StateError` z `.first` w konstruktorze. Rejestr nigdy nie jest pusty; zostawiam. |
| 7 | N | ⏳ | `map_layers_repository.dart` | Cache wyrzuca najstarsze *dodane* miejsce (FIFO), nie najdawniej *użyte* (LRU). Przy 20 miejscach bez znaczenia. |

Sprawdzone bez uwag: wyścigi (numer ładowania, testy: stara odpowiedź i stary błąd ignorowane, przełączenie w trakcie
ładowania), `dispose` (brak powiadomień po zamknięciu, test), błędy nie zostają w cache (test), brak martwego kodu,
brak HTTP poza `ApiClient`.

## Recenzja #2 (po iteracjach 4–5: ekran, mapa, panel, nawigacja)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 8 | Ś | ✅ | `overlay_map.dart` | Etykieta „Moje pole” liczyła środek z ramki obrysu, choć `Parcel` ma już `center` (z backendu). Mapa dostaje teraz całe `Parcel`. |
| 9 | Ś | ✅ | `overlay_panel.dart` | Po „Pokaż przykładowe dane” nie było drogi powrotu do prawdziwych danych (przycisk „Spróbuj ponownie” był tylko w stanie błędu). Dodany także przy danych przykładowych + test. (Znalezione już w iteracji 4.) |
| 10 | Ś | ✅ | `overlay_panel.dart` | `Semantics(excludeSemantics: true)` na przycisku nakładki usuwało akcję „tap” dla czytnika ekranu. Teraz `MergeSemantics` – „Gleba, przycisk, wybrane”, z akcją; test. (Iteracja 4.) |
| 11 | Ś | ✅ | `overlay_map.dart` | `SimpleAttributionWidget` z flutter_map przepełniał się (Row) na wąskim ekranie i pokazywał „© ©”. Zastąpiony własnym, zawijanym podpisem z ARB. W `components/parcel_map.dart` naprawione w pętli porządkowej (P1). |
| 12 | Ś | ✅ (P1) | `overlay_map.dart` ↔ `components/parcel_map.dart` | Duplikacja: `_SingleWorldCrs` i pigułka z ikoną (`_FieldLabel` ≈ `_MapLabel`). Oba prywatne w `parcel_map.dart`, którego nie wolno było ruszać. Do wyciągnięcia do wspólnego pliku w pętli porządkowej. |
| 13 | Ś | 📝 | cały ekran | AGENTS.md: „każdy ekran ma przycisk czytania na głos (`flutter_tts`)”. Zależności nie ma w projekcie, a ZAKRES pozwalał dodać tylko flutter_map/latlong2/http. Żaden inny ekran też go nie ma. |
| 14 | N | ⏳ | `overlays_screen.dart` | `ListenableBuilder` słucha całego `SelectedPlotStore`, więc ekran przebudowuje się także przy `setNearby` z zakładki Mapa (choć jest niewidoczny). Tanie; zostawiam. |
| 15 | N | ⏳ | `overlay_map.dart` | Etykiety na mapie są czytane przez czytnik ekranu podwójnie (te same słowa są w panelu). Niegroźne. |

Sprawdzone bez uwag: `dispose` (kontroler, `MapController`, słuchacz store), wyścig „zmiana pola w trakcie ładowania”
(kontroler + test ekranu), ładowanie dopiero po otwarciu zakładki (test), kontrast tekstu na kolorowej etykiecie
(czarny/biały wg WCAG, min. 4,58:1 dla każdego koloru), stany ładowania/błędu z `liveRegion`, brak tekstów na sztywno
w nowych plikach (grep z AGENTS.md znajduje tylko starą linię w `parcel_map.dart`).

**Wysoki priorytet: brak.**

## Recenzja #3 (po iteracjach 7–8: dostępność, druga nakładka; przegląd całego diffu względem `main`)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 16 | Ś | ✅ | `monthly_layer_overlay.dart` | Backend ostrzega, że NASA POWER może nie mieć najnowszych miesięcy (`null`). Wtedy nakładka pokazywała „Brak danych”, choć wcześniejszy miesiąc ma wartość. Teraz: najnowszy miesiąc z wartością (miesiąc jest podpisany). Gdy brak wartości w ogóle – „Brak danych” bez mylącego „styczeń 2016”. Testy. |
| 17 | N | ✅ | `overlay_map.dart` | `_ValueLabel` i `_FieldLabel` różniły się ikoną i obramowaniem – połączone w `_MapPill`. |
| 18 | Ś | 📝 | backend / `monthly_layer_overlay.dart` | Etykiety legend z backendu tylko po polsku – w wersji EN legenda wilgotności jest po polsku. Opis i propozycja w PROGRESS.md („Do decyzji”). |
| 19 | N | ⏳ | `map_layers_repository.dart` | `useMock` nie jest używany przez aplikację (dane demo idą przez `demo()` na żądanie użytkownika). Zostawiony dla zgodności z innymi repozytoriami (AGENTS.md) i przetestowany. |
| 20 | N | ⏳ | `overlay_controller.dart` | Getter `place` używany tylko w testach. Tani, zostawiam. |

Sprawdzone bez uwag: przełączanie nakładek po błędzie „złe dane” jednej z nich (druga może się wczytać, bo odpowiedź
zostaje), odporność parsera serii na 10 rodzajów uszkodzeń, wspólna reguła progów z backendem (granice w testach),
kontrakt `FieldShift/docs/map-layers.md` ↔ parser.

**Wysoki priorytet: brak** (w żadnej z trzech recenzji nie było pozycji „W”).

## Pętla porządkowa (`chore/cleanup-loop`) – przegląd całego frontendu

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 21 | Ś | ✅ P1 | `components/parcel_map.dart` | `SimpleAttributionWidget`: overflow na telefonie przy dużej czcionce, „© ©”, jedyny tekst na sztywno w aplikacji. Wspólne `MapAttribution`, `MapPill`, `SingleWorldCrs`. |
| 22 | Ś | ✅ P2 | `crop_summary_card.dart`, `crop_details_sheet.dart`, `nearby_plot_list.dart` | Liczby bez formatu języka („+3.5%”, „1.4 km”, ceny bez separatora tysięcy). |
| 23 | Ś | ✅ P3 | `map_search_bar.dart` | Brak `finally`: wyjątek w wyszukiwaniu zostawiał pole na zawsze wyłączone. |
| 24 | N | ✅ P4 | `pages/area_map_page.dart` | Nieudane wczytanie działek blokowało ponowną próbę w tym samym miejscu. |
| 25 | Ś | ✅ P5 | `api/api_client.dart` | Limit czasu na zapytanie; 40 s dla warstw mapy (= #5). |
| 26 | N | ✅ P6 | `plot_input.dart` | Importy `package:` zamiast względnych. |
| 27 | **W** | ✅ P7 | `pages/plot_page.dart` + `plot_input.dart` | „Zapisz działkę” czyściło formularz, nic nie zapisując – utrata danych bez komunikatu. |
| 28 | N | ✅ P8 | repozytoria | Nowy `http.Client` na każdą plakietkę ceny / arkusz; teraz `ApiClient.shared`. |
| 29 | N | ✅ P10 | `price_repository.dart`, `crop_details_sheet.dart` | Utracony stack trace; zbędne przerysowania wykresu. |
| 30 | Ś | 📝 | `lib/components`, `lib/pages` ↔ `lib/widgets`, `lib/screens` | AGENTS.md opisuje `widgets/` i `screens/`, kod używa `components/` i `pages/`; nakładki (z zadania) są w `widgets/`/`screens/`. Teraz są oba układy. Przeniesienie to duża zmiana nazw plików (konflikty u zespołu) – decyzja zespołu: przenieść albo poprawić AGENTS.md. |
| 31 | Ś | 📝 | `price_repository.dart` | Zapasowa (zapisana) kopia cen trafia do pamięci podręcznej na całą sesję: gdy backend wróci, aplikacja do restartu pokazuje ceny z pliku. Nie zmieniałem: bez cache arkusz przy zawieszonej sieci czekałby 15 s zamiast od razu pokazać kopię. Do decyzji. |
| 32 | N | ⏳ | `crop_repository.dart` | Bez pamięci podręcznej: każdy arkusz szczegółów pobiera cały katalog (~21 kB). Tanie; zostawiam. |

Bez uwag po sprawdzeniu: wszystkie ekrany przy 1,5× na telefonie w PL i EN (test P9), `SelectedPlotStore`
(błędne zapisane dane są ignorowane), `TrendingCropsPage` (przeładowanie po zmianie języka), `CropMultiSelector`
(`dispose`), brak tekstów na sztywno (grep z AGENTS.md pusty).

**Wysoki priorytet: brak otwartych** (jedyny „W”, #27, naprawiony).

## Recenzja #4 (runda 3: legendy EN, miesiące, lista nakładek, 5 nowych nakładek)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 33 | Ś | ✅ | `overlay_panel.dart` | (ze zrzutów) Na telefonie przy 1,5× tytuł panelu spychał wartość pod ekran – tytuł tylko na szerokim ekranie. |
| 34 | N | ⏳ | `overlay_controller.dart` | Po cofnięciu o kilka miesięcy nie ma skrótu „wróć do ostatniego miesiąca” (trzeba klikać ▶). Nowe miejsce i „Spróbuj ponownie” wracają do ostatniego. Mała rzecz; do rozważenia z użytkownikami. |
| 35 | N | ⏳ | `overlays/*_overlay.dart` | 6 klas nakładek miesięcznych różni się tylko id, ikoną i tekstami – świadomie (zadanie: „nowa nakładka = jedna klasa + jedna linia”). Gdyby było ich > 10, lepsza byłaby jedna klasa z parametrami. |
| 36 | Ś | 📝 | backend | Backend wysyła `stats.trendPerDecade`. Nie pokazuję: trend z 10 lat danych jest bardzo niepewny (np. opady −95 mm/dekadę), a odpowiedź nie mówi, czy roczna wartość to suma czy średnia (`YearlyAggregation` jest tylko w backendzie). Jeśli ma być – backend powinien dodać jednostkę trendu i jego niepewność. |
| 37 | N | ⏳ | `monthly_layer_overlay.dart` | Etykieta legendy liczy zakres (`NumberFormat`) przy każdym budowaniu. Koszt pomijalny (4 pozycje). |

Sprawdzone bez uwag: przełączanie nakładek przy wybranym miesiącu (miesiąc zostaje, gleba go ignoruje), granice
miesięcy (przyciski wyłączone na końcach, kontroler ignoruje krok poza zakres), wybrany miesiąc bez danych („Brak
danych”, bez cofania), nowe miejsce resetuje miesiąc, semantyka listy nakładek i przycisków miesiąca, brak tekstów na
sztywno, wszystkie legendy EN bez polskich słów (test), PL = backend (test).

**Wysoki priorytet: brak.**

## Recenzja #5 (`feat/read-aloud`)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 38 | N | ⏳ | `read_aloud_button.dart` | Wyścig ikon: gdy przycisk na innej zakładce (`IndexedStack` nie usuwa ekranów) zacznie czytać, zanim przyjdzie sygnał „anulowano” od poprzedniego czytania, ikona nowego przycisku może wrócić do „czytaj”, choć czyta. Dźwięk jest poprawny. Dziś jest tylko jeden przycisk w aplikacji – problem pojawi się, gdy dojdą kolejne ekrany. Naprawa: numerować wypowiedzi w `TtsSpeaker` i ignorować stare zdarzenia. |
| 39 | N | ⏳ | `read_aloud_button.dart` | Tempo mowy domyślne. Dla starszych osób wolniejsze może być lepsze, ale skala tempa różni się między Androidem (0,5 = normalnie) i przeglądarką (1,0 = normalnie) – nie zgadywałem. Do sprawdzenia z użytkownikami. |
| 40 | Ś | 📝 | `pubspec.yaml` | Nowa zależność `flutter_tts` – decyzja zespołu (AGENTS.md jej wymaga). Gałąź osobna, żeby można było nie scalać. |

Sprawdzone bez uwag: silnik mowy tworzony dopiero przy pierwszym użyciu (testy i ekrany bez czytania go nie
uruchamiają), zatrzymanie po wyjściu z ekranu, błąd silnika → komunikat i powrót przycisku, brak tekstów na sztywno.

## Recenzja #6 (`feat/heatmap`: heatmapa okolicy)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 41 | Ś | ✅ | `overlay_heatmap.dart` | Przy pełnym wygładzaniu komórka bez danych NASA była „łatana” wartościami sąsiadów (zgadywanie). Teraz w komórce bez danych mapa jest przezroczysta (test). |
| 42 | Ś | ⏳ | backend `MapLayersService` | Zapytanie punktowe czeka do 60 s na SoilGrids, gdy ten nie odpowiada (dziś się zdarzyło); aplikacja poddaje się po 40 s i pokazuje błąd, choć dane NASA są gotowe. Siatka tego problemu nie ma (bez SoilGrids). Propozycja: krótszy limit dla SoilGrids w mapie warstw (np. 10 s) – gleba i tak jest opcjonalna. |
| 43 | N | ⏳ | `overlay_map.dart` | Etykieta wartości stoi ok. 25 km na północ od pola (górna krawędź koła), na heatmapie też. Przy wybranym polu nie zasłania „Moje pole”; bez pola wygląda jak wartość dla Warszawy. Do rozważenia: etykieta tuż nad znacznikiem pola. |
| 44 | N | 📝 | backend | Ostrzeżenie „Stres roślinny i ryzyko erozji to wskaźniki szacunkowe” wraca też z siatki, na której erozji nie ma – tekst backendu, nie zmieniałem. |

Sprawdzone: wartość komórki pola = wartość karty dla każdej warstwy (test backendu i frontendu, oraz na żywo: lipiec
2025, temperatura/opady/wilgotność), siatka 5×5 z NASA w ~5 s, potem z pamięci podręcznej, niedozwolona warstwa → 400,
każdy kolor heatmapy jest kolorem stopnia legendy (test), heatmapa podąża za miesiącem i nakładką, gleba i erozja
zostają kołem, błąd siatki → koło bez komunikatu o błędzie, wyścig starych odpowiedzi siatki (test), zrzuty ekranu
w przeglądarce (wilgotność grudzień, opady lipiec).

**Wysoki priorytet: brak.**

## Recenzja #7 (heatmapa dociągana przy przesuwaniu, ukrywana po oddaleniu)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 45 | Ś | ✅ | `overlay_map.dart` | Kamera dopasowywała się do całej heatmapy, więc każdy nowy kawałek przesuwałby widok. Teraz dopasowanie tylko do kawałka z polem (`heatmapHome`), stałego także przy ukryciu po oddaleniu. |
| 46 | N | ⏳ | `overlay_controller.dart` | Kawałka, który się nie wczytał, nie ponawiam aż do zmiany miejsca lub „Spróbuj ponownie” (żeby nie zasypywać NASA przy każdym ruchu mapy). |
| 47 | N | 📝 | `overlay_controller.dart` | Kawałki liczone od kawałka z polem, więc dwa pola w różnych komórkach NASA mają inaczej przesunięte kawałki i nie dzielą pamięci podręcznej backendu. Wyrównanie do stałej siatki dałoby wspólny cache, ale pierwszy widok potrzebowałby wtedy do 4 kawałków zamiast 1. |

Sprawdzone: przesunięcie mapy → doczytanie kawałków (na żywo i test), najwyżej 2 naraz, powrót bez nowych zapytań,
> 3×3 kawałki → heatmapa znika z napisem „Przybliż mapę…” i nic się nie pobiera, przybliżenie przywraca, kawałek
z błędem zostaje pusty, dane demo bez dociągania, łączenie bez szwów (test `merge`).

**Wysoki priorytet: brak.**

## Recenzja #8 (`feat/parcel-data`: dane działki z Geoportalu, dostawcy, cache w PostgreSQL)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 48 | Ś | ✅ | `EgibLandClassProvider.cs` | Powiat poznański publikuje w integracji EGiB tylko numer i miejsce działki, bez powierzchni i klas – wcześniej sekcja była „ok” z pustą listą; teraz „noData” (test). |
| 49 | Ś | 📝 | `LandClassCode.cs` | Nazwy klas bonitacyjnych (np. IVb „orne średnie gorsze”, łąki III „dobre”) wpisane z rozporządzenia o gleboznawczej klasyfikacji gruntów z pamięci, nie z dokumentu – do sprawdzenia z tekstem rozporządzenia. Kody kompleksów, typów i gatunków gleb są przepisane z legendy mapy glebowo-rolniczej (PDF Geoportalu Podlaskiego). |
| 50 | N | ⏳ | `PostgresProviderCache.cs` | Wygasłe wiersze `provider_cache` nie są usuwane (są tylko nadpisywane przy kolejnym pytaniu). Przy wielu działkach warto dodać okresowe `DELETE … WHERE expires_at < now()` (indeks na `expires_at` już jest). |
| 51 | N | ✅ | `ParcelDetailsService.cs` | Wyszukanie działki w ULDK nie jest w cache – drugie zapytanie o tę samą działkę trwa ~0,7 s zamiast ~0,1 s. Wystarczy, bo ULDK jest szybkie. |
| 52 | N | 📝 | `MapLayersService.cs` | SoilGrids w mapie warstw i profilu pola idzie teraz przez cache w PostgreSQL (180 dni): problem #42 (czekanie do 60 s) zostaje tylko przy pierwszym pytaniu o dany punkt. |

Sprawdzone na żywo: działka 141205_2.0008.60 (Chrośla) – klasy RIVb/RIVa/LzrRIV, kompleks 5 „żytni dobry”, gleby
bielicowe, pgl na gs od 50–100 cm, spadek 0,5 % („płasko”, 150 punktów NMT), SoilGrids „Lekka”; pierwsze zapytanie
~10 s, drugie 0,7 s z cache (4 wiersze w `provider_cache`); po numerze działki to samo; punkt poza Polską → 404;
złe współrzędne → 400; Kraków (zabudowa) → klasy B/Ba/Bi, „tereny zabudowane”, SoilGrids „noData”; baza
niedostępna → zapytania działają bez cache (test).

**Wysoki priorytet: brak.**

## Recenzja #9 (`feat/soil-map-ui`: flaga bez paska, przycisk „Pokaż moje pole”, gleba z Geoportalu)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 53 | Ś | ✅ | `overlay_map.dart` | Kamera obejmowała cały kawałek heatmapy (250 km), więc nowe pole w tym samym kawałku nie zmieniało widoku. Teraz pole na środku ± jedna komórka NASA, plus przycisk powrotu (test). |
| 54 | Ś | 📝 | backend `SoilMapTileProvider` | WMS mapy glebowo-rolniczej co jakiś czas odpowiada 503 (dziś kilka razy). Klient ponawia (standard resilience), a nieudany kafelek jest przezroczysty z `max-age=300` i nie trafia do cache. |
| 55 | N | ✅ | `plot_page.dart` | Pływająca flaga zachodziła na prawy górny róg karty „Moja działka” – karta ma teraz odstęp z prawej. |
| 56 | N | 📝 | `soil_quality_overlay.dart` | Nazwy kompleksów, typów i gatunków gleb przychodzą z backendu po polsku – w wersji angielskiej zostają polskie (jak dawniej etykiety backendu). |
| 57 | N | ✅ | `overlay_controller.dart` | Dane działki pobierane są po punkcie (środek działki), nie po numerze działki – przy działkach wklęsłych środek może wypaść na sąsiedniej działce. Lepiej przekazać numer działki ze `SelectedPlotStore`. |

Sprawdzone na żywo: kafelki mapy glebowej przez backend (17 kB, potem z `tile_cache` w 3 ms), legenda z kolorami
z obrazka legendy WMS, karta „kompleks żytni dobry” z typem gleby, uziarnieniem, klasami z ewidencji i rokiem badania,
fallback na SoilGrids bez danych działki (test), NASA niedostępne → gleba nadal widoczna (test), zrzuty: telefon
i szeroki ekran.

**Wysoki priorytet: brak.**

## Recenzja #10 (`feat/plant-stress-erosion`)

| # | Prio | Status | Plik | Uwaga |
|---|---|---|---|---|
| 58 | N | 📝 | `MapLayersService.cs` | Erozja szuka działki w ULDK przy każdym nowym punkcie (wynik 24 h w pamięci, spadek 365 dni w PostgreSQL). Gdy ULDK nie odpowiada, erozja liczona jest jak dawniej, bez spadku (z ostrzeżeniem). |
| 59 | N | 📝 | `MapLayersService.cs` | Podatność gleby (K) w erozji dalej z SoilGrids, nie z mapy glebowo-rolniczej – mapa ma kompleksy, nie skład procentowy. |

Sprawdzone na żywo: działka w Chrośli – spadek 0,5 % (płasko), źródło erozji „…spadek działki: NMT GUGiK”, bez
ostrzeżenia o braku nachylenia; drugi punkt (Małopolska) 2 %; stres roślin w odpowiedzi i w siatce heatmapy;
test: większy spadek → nie mniejsza erozja.

**Wysoki priorytet: brak.**

## Recenzja #11 (`feat/parcel-lookup-cache`)

Wyszukanie działki (ULDK) w cache PostgreSQL (`parcel-at.v1` po punkcie ~1 m, `parcel-id.v1` po numerze, 30 dni,
„brak działki” 1 dzień) – dane działki i erozja nie pytają ULDK ponownie (#51). Aplikacja pyta o wybrane pole po
numerze działki (#57). Testy: drugie zapytanie o tę samą działkę/punkt nie idzie do rejestru; obrys przeżywa zapis
w cache.

**Wysoki priorytet: brak.**

