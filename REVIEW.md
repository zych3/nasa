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
