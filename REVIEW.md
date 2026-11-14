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
| 5 | Ś | 📝 | `api/api_client.dart` (poza zakresem) | Limit czasu `ApiClient` to 15 s, a pierwsze zapytanie o nowe miejsce trwa 5–10 s (NASA POWER + SoilGrids; u mnie 6,2 s). Przy wolnym NASA klient przerwie, a backend anuluje swoje zapytanie (`CancellationToken`), więc „Spróbuj ponownie” zaczyna od zera. Rozważyć dłuższy limit dla tego endpointu (np. parametr `timeout` w `getJson`). Nie zmieniałem – `lib/api/` poza zakresem. |
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
| 11 | Ś | ✅ | `overlay_map.dart` | `SimpleAttributionWidget` z flutter_map przepełniał się (Row) na wąskim ekranie i pokazywał „© ©”. Zastąpiony własnym, zawijanym podpisem z ARB. Ten sam problem jest w `components/parcel_map.dart` (poza zakresem) – patrz pętla porządkowa. |
| 12 | Ś | ⏳ | `overlay_map.dart` ↔ `components/parcel_map.dart` | Duplikacja: `_SingleWorldCrs` i pigułka z ikoną (`_FieldLabel` ≈ `_MapLabel`). Oba prywatne w `parcel_map.dart`, którego nie wolno było ruszać. Do wyciągnięcia do wspólnego pliku w pętli porządkowej. |
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
