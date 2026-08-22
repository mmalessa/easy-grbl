# Refactor TODO — EasyGRBL

Backlog refaktoringu zebrany z przeglądu całego `lib/` (~40 plików, ~8400 linii) pod kątem: powtórzeń (DRY), spójności nazewnictwa, zasad SOLID (głównie SRP) i ogólnej czytelności. Każdy punkt ma konkretne odniesienie do plików/linii i uzasadnienie ("dlaczego to boli"), żeby dało się go realizować pojedynczo, bez ponownej analizy całości.

Uwaga: to przegląd strukturalny (wzorce, duplikaty, rozmiar klas), nie pełny line-by-line audit największych plików (`layer_settings_panel.dart`, `machine_settings_dialog.dart`). Numery linii mogą się lekko przesunąć do czasu realizacji danego punktu — do zweryfikowania na bieżąco.

Realizujemy krok po kroku, w kolejności z sekcji **Podsumowanie** na końcu.

---

## P0 — Bezpieczne usunięcia (dead code) ✅ zrobione (commit `8a8f7a5`)

### 1. Usuń nieużywany legacy parser SVG oparty na regexach
- **Pliki:** `lib/services/svg_path_parser.dart` (198 linii), `lib/services/svg_path_model.dart` (11 linii), `lib/widgets/svg_paths_painter.dart` (40 linii)
- **Dowód:** `SvgPathParser`, `SvgPathModel`, `SvgPathsPainter` nie są referencjonowane nigdzie poza własnym plikiem (potwierdzone grepem po całym `lib/`). Aplikacja parsuje SVG wyłącznie przez `SvgTreeParser` (drzewo węzłów, warstwy, transformacje) — ten regexowy parser to najwyraźniej wcześniejsza iteracja, zastąpiona i pozostawiona w repo.
- **Ryzyko:** brak — kod nieosiągalny z żadnego ekranu.
- **Rozmiar:** S. ~250 linii do usunięcia.

### 2. Usuń nieużywany ekran `SvgViewerScreen`
- **Plik:** `lib/screens/svg_viewer/svg_viewer_screen.dart` (238 linii) — cały katalog `lib/screens/svg_viewer/`
- **Dowód:** nigdzie nienawigowany; `HomeScreen` jest jedynym ekranem aplikacji (`main.dart` → `EasyGrbl` → `HomeScreen`).
- **Ryzyko:** brak. **Uwaga:** `SvgPreviewWidget` zostaje — jest też używany przez `HomeScreen`, tylko sam ekran `SvgViewerScreen` jest martwy.
- **Rozmiar:** S. ~238 linii do usunięcia.

**Razem P0: 487 linii martwego kodu usunięte, `flutter analyze` czyste, `flutter test` bez nowych regresji (pre-istniejący overflow w `right_panel.dart` niezwiązany z tą zmianą).**

---

## P1 — Duplikacja logiki domenowej (warstwa `services`)

### 3. Zunifikuj „chodzenie po drzewie `SvgNode` z dziedziczeniem efektywnej operacji” ✅ zrobione
Ten sam algorytm — pomiń węzeł gdy `!enabled`, policz `own = node.settings.operationType`, `eff = own != skip ? own : inherited`, rekurencja z propagacją `eff`/`effSettings` do dzieci — jest zaimplementowany **osobno w 6 miejscach**:

| # | Miejsce | Co robi |
|---|---|---|
| a | `GrblService.countJobSteps` — `lib/services/grbl_service.dart:81` | liczy kroki/passy do podglądu w UI |
| b | `GrblMockService._collectSteps`/`walk` — `lib/services/grbl_mock_service.dart:235` | generuje kroki animacji mocka |
| c | `GcodeGenerator._walkNodes` — `lib/services/gcode_generator.dart:54` | generuje G-code |
| d | `GcodeGenerator.computeActiveBounds`/`walk` — `lib/services/gcode_generator.dart:377` | **druga kopia w tym samym pliku**, liczy bounding box |
| e | `computeToolpath`/`_walkNodes` — `lib/services/toolpath.dart:65` | generuje podgląd toolpath na canvasie |
| f | `SvgDocumentPainter._paintNode` — `lib/widgets/svg_document_painter.dart:230` | rysuje warstwy w podglądzie (wariant bez `effectiveSettings`) |

- **Dlaczego to boli:** każda zmiana reguły dziedziczenia (np. nowy wyjątek w propagacji ustawień) wymaga poprawki w 6 miejscach. `computeActiveBounds` (d) już dziś jest okrojoną kopią (c) w tym samym pliku — sygnał, że kopiowanie zamiast reużycia jest tu utrwalonym nawykiem.
- **Sugerowane podejście:** wydzielić jeden generator/iterator, np. `Iterable<EffectiveNode> walkEffectiveNodes(SvgDocument doc)` w nowym `lib/services/svg_node_walker.dart`, zwracający `(node, transform, effectiveOp, effectiveSettings)`; przepisać a–f jako jego konsumentów.
- **Ryzyko:** średnie — to serce generowania G-code. Zrobić na końcu (po uporządkowaniu mniejszych duplikatów 4–7) i pokryć testami przed/po (patrz sekcja Podsumowanie).
- **Wynik:** nowy `lib/services/svg_node_walker.dart` (101 linii) z dwoma warstwami:
  - `resolveNode(...)` — czysta matematyka jednego kroku (transform + visible + effectiveOp + effectiveSettings), to jest właściwie zduplikowana logika.
  - `walkSvgNodes(roots, visit)` — driver rekurencji zbudowany na `resolveNode`, przycina poddrzewa wyłączonych węzłów (jak oryginalne `continue`), używany przez (a)-(e).
  - `SvgDocumentPainter` (f) **celowo NIE** korzysta z `walkSvgNodes` — ma własną rekurencję, bo (1) pozycjonuje przez stos transformacji canvasu (`applySvgTransform`/`canvas.save/restore`), nie przez jawną macierz, i zmiana na jawną macierz zmieniłaby wizualnie grubość obrysu przy węzłach z lokalnym `scale()` (stroke width przestałby skalować się z lokalną transformacją), (2) musi odwiedzać też wyłączone węzły, żeby narysować je wyszarzone, czego `walkSvgNodes` świadomie nie robi. Painter dzieli tylko naprawdę uniwersalny ułamek logiki: `resolveEffectiveOp(node, inheritedOp)` (1 linia, `own != skip ? own : inherited`), z komentarzem tłumaczącym dlaczego reszta zostaje osobno.
  - Przy okazji: `effectivePassesFor`/`isActiveOp` jako nazwane, współdzielone reguły (fill zawsze 1 przebieg; „aktywny” = ma pathData + effectiveOp niepusty i różny od skip).
- **Naprawiony bug (za zgodą, patrz decyzja niżej):** `countJobSteps` liczyło `n.settings.passes` (własne pole węzła) zamiast odziedziczonych ustawień — jedyna z 6 implementacji tak robiąca. Naprawione przy unifikacji: teraz liczy `effectivePassesFor(effectiveOp, effectiveSettings)` jak reszta. Dodatkowo wyrównane do kanonicznej reguły „Fill = zawsze 1 przebieg" (wcześniej `countJobSteps` sumowało `passes` również dla Fill, mimo że Fill fizycznie nie powtarza przebiegów w żadnym z pozostałych 5 miejsc) — to nie było osobno pytane, ale to ten sam, jednorazowy fix tej samej linijki, więc zrobione razem.
- **Weryfikacja:** throwaway test budujący SVG z głębokim dziedziczeniem (3 poziomy grup), wyłączonym węzłem, fill+cut+engrave, dla laser i mill — porównanie `git stash`: wygenerowany **G-code, bounding box i geometria toolpath są bajt-identyczne** przed/po dla obu typów maszyn; jedyna różnica w całym porównaniu to `countJobSteps`: `(passes: 5, paths: 4)` → `(passes: 11, paths: 4)` — dokładnie oczekiwany efekt zatwierdzonej naprawy. Test i pliki porównania usunięte po weryfikacji.
- **Rozmiar:** L.

### 4. Zunifikuj obliczanie przesunięcia dla Cut (kerf compensation) ✅ zrobione
- Identyczna funkcja `_cutOffsetDelta(machineSettings, layerSettings)` istnieje **1:1** w `lib/services/grbl_mock_service.dart:378-385` i `lib/services/toolpath.dart:102-109`; ten sam `switch` jest też wpisany inline w `lib/services/gcode_generator.dart:103-107`.
- **Sugerowane podejście:** przenieść jako metodę do `MachineSettings` (obok już istniejącego `effectiveDiameterAt`) albo do helpera przy okazji punktu 3.
- **Ryzyko:** niskie — czysto matematyczna funkcja.
- **Rozmiar:** S.

### 5. Zunifikuj „czyszczenie linii G-code przed wysłaniem” ✅ zrobione
- Ten sam ciąg `.split('\n').map(strip-inline-comment).where(isNotEmpty).toList()` występuje **4×**: `lib/services/grbl_serial_service.dart:285` (`startJob`) oraz `lib/screens/home/home_screen.dart:267, 330, 393` (`_startFocusTestJob`, `_startKerfTestJob`, `_startSpotTestJob`).
- **Sugerowane podejście:** jedna funkcja `List<String> stripGcodeComments(String gcode)`, np. w `gcode_generator.dart`, używana we wszystkich 4 miejscach.
- **Ryzyko:** brak.
- **Rozmiar:** S.

### 6. Zunifikuj formatowanie liczb do G-code ✅ zrobione (commit `75b52c9`)
- `static String _f(double v) => v.toStringAsFixed(3);` zduplikowane identycznie w `gcode_generator.dart:402`, `gcode_templates.dart:168`, `grbl_mock_service.dart:365`.
- **Sugerowane podejście:** jedna top-level funkcja, np. w `gcode_generator.dart` (eksportowana) albo mały `gcode_format.dart`.
- **Ryzyko:** brak.
- **Rozmiar:** S.

### 7. `applySvgTransform` duplikuje matematykę `SvgAffine` ✅ zrobione
- `lib/services/svg_transform.dart` (`applySvgTransform`, używana w `svg_document_painter.dart`) parsuje ten sam string transformu SVG (`translate`/`scale`/`rotate`/`matrix`) co `SvgAffine.fromSvgString` w `lib/services/affine.dart` — dwie osobne implementacje tej samej matematyki, które mogą się rozjechać (np. `rotate` wokół punktu obrotu liczony inną metodą w każdej z nich).
- **Sugerowane podejście:** `applySvgTransform(canvas, transform) => canvas.transform(SvgAffine.fromSvgString(transform).toFloat64());` — jedna linia zamiast ~30, i tylko jedno miejsce z matematyką transformacji SVG.
- **Ryzyko:** niskie, łatwe do zweryfikowania wizualnie (podgląd SVG powinien wyglądać identycznie przed/po).
- **Rozmiar:** S.

### 8. `SettingsService`: 22 pola ręcznie mapowane w `load()`/`save()` ✅ zrobione
- `lib/services/settings_service.dart` — każde z 22 pól `MachineSettings` wymaga osobnej linii w `load()` i w `save()`, z ręcznie wpisanym stringiem klucza (`'${_prefix}xxx'`). Łatwo o rozjazd (dodanie pola do `MachineSettings`, a zapomnienie o `save()`) — dziś nic tego nie pilnuje.
- **Sugerowane podejście do przedyskutowania:** rozważyć `MachineSettings.toMap()`/`fromMap()` (obok `copyWith`), żeby `SettingsService` iterował po mapie zamiast wypisywać 22 klucze × 2. Mniej inwazyjna alternatywa: zostawić jak jest, ale dodać test „save → load == original”, żeby przyszłe pola nie znikały cicho.
- **Ryzyko:** niskie, ale nie zmieniać kluczy w `SharedPreferences` przy okazji (zgodność z zapisanymi ustawieniami istniejących użytkowników).
- **Rozmiar:** M.
- **Wynik:** wybrane podejście `toMap()`/`fromMap()`. `MachineSettings.toMap()`/`fromMap()` (obok `copyWith`) niosą teraz jedyną listę pól; `SettingsService` (70→35 linii) w ogóle nie zna nazw pól — tylko iteruje po mapie i prefiksuje klucze. Zachowane 1:1 klucze `SharedPreferences` (bez migracji) oraz **celowo różne od `MachineSettings()`** domyślne wartości `maxSpindleSpeed`/`maxFeedRate`/`toolDiameter` dla świeżej instalacji (24000 RPM / 3000 mm/min / 3.175 mm zamiast konstruktorowych 1000/10.0/2.0) — udokumentowane w komentarzu przy `fromMap`, bo to nieoczywiste i łatwe do przypadkowego "ujednolicenia" przy przyszłej zmianie. Zweryfikowane throwaway testem (`save → load` round-trip + fresh-install defaults), potem usuniętym.

---

## P2 — Duplikacja w warstwie widoków (UI)

### 9. `FocusTestPanel` / `KerfTestPanel` / `SpotTestPanel` — ~150 linii identycznego kodu ×3 ✅ zrobione
- `lib/widgets/focus_test_panel.dart`, `kerf_test_panel.dart`, `spot_test_panel.dart`: metody `_header`, `_label`, `_infoRow`, `_powerSlider`, `_speedStepper`, `_speedBtn` są kopiami 1:1 (różni się tylko tytuł/ikona nagłówka i nazwa pola configu podpiętego pod slider).
- **Sugerowane podejście:** wspólny szkielet, np. `_TestPanelScaffold({icon, title, onClose, child})`, plus reużywalne komponenty `PowerSlider`, `SpeedStepper`, `InfoRow` w np. `lib/widgets/test_panel/`. Trzy panele redukują się do własnej specyficznej zawartości (legenda kerf/spot, info-rows).
- **Ryzyko:** niskie — czysto prezentacyjne, łatwe do zweryfikowania side-by-side.
- **Rozmiar:** M.
- **Wynik:** nowy `lib/widgets/test_panel_common.dart` z `TestPanelScaffold`, `TestPanelLabel`, `TestPanelInfoRow`, `TestPanelPowerSlider` (parametryzowany `min`/`divisions` — Kerf ma inny zakres niż Focus/Spot), `TestPanelSpeedStepper`. Trzy panele skróciły się z 181/219/216 do 45/86/80 linii, każdy zostawiając tylko swoją unikalną zawartość (`_powerLegend` w Kerf, `_legend` w Spot).

### 10. Ten sam mały „przycisk krokowy” (stepper icon button) reimplementowany ~8 razy ✅ zrobione
- `lib/widgets/layer_settings_panel.dart` — 4 osobne klasy (`_DepthCounter:504`, `_LinesPerMmCounter:596`, `_SpeedCounter:676`, `_Counter:730`), każda definiuje własną metodę `_btn(icon, onTap, cs)`, niemal identyczną (28×26, `Material`+`InkWell`+`Icon`, kolor aktywny/nieaktywny).
- `lib/widgets/machine_settings_dialog.dart:910` — `_stepBtn`, kolejny wariant.
- `lib/widgets/focus_test_panel.dart` / `kerf_test_panel.dart` / `spot_test_panel.dart` — `_speedBtn`, kolejny wariant (32×28).
- `lib/widgets/run_panel.dart:37` — `_iconBtn`, dodatkowo z code smellem: parametr `ColorScheme? cs` jest opcjonalny, a w środku `cs ?? (throw StateError('_iconBtn requires cs'))` — de facto wymagany, powinien być `required ColorScheme cs`.
- **Sugerowane podejście:** jeden reużywalny widget, np. `IconStepperButton({icon, onTap, color, size})` w `lib/widgets/icon_stepper_button.dart`. To najczęściej powielany fragment kodu w całym repo — dobra, widoczna wygrana.
- **Ryzyko:** niskie, ale dotyka wielu plików naraz — zrobić jako osobny PR, przetestować wizualnie każde miejsce użycia.
- **Rozmiar:** M.
- **Wynik:** `IconStepperButton` (parametry `icon`, `onTap`, `color`, `width`/`height`/`iconSize`/`activeAlpha` z sensownymi defaultami) zastąpił 7 z 8 miejsc (4× `layer_settings_panel.dart`, 3× `_speedBtn` w test-panelach, `_stepBtn` w `machine_settings_dialog.dart`). `_iconBtn` w `run_panel.dart` **celowo zostawiony osobno** — inny przepis wizualny (tło z `surfaceContainerLow`, nie tinted-color, promień 5 nie 4) i tylko jedno miejsce użycia, więc wrzucenie go do wspólnego widgetu byłoby nadmiarową abstrakcją, nie deduplikacją. Naprawiony tylko sam code smell: `ColorScheme? cs` (opcjonalny, a w środku rzucający `StateError` gdy `null`) zmieniony na `required ColorScheme cs`.

### 11. `machine_settings_dialog.dart` — ~11 niemal identycznych metod `_xxxRow` ✅ zrobione
- `_sMaxRow:729`, `_spotSizeRow:749`, `_maxSpindleSpeedRow:759`, `_maxFeedRateRow:770`, `_toolDiamRow:781`, `_bladeAngleRow:804`, `_safeHeightRow:827`, `_travelFeedRateRow:850`, `_baudRateRow:924` — każda to `Row(label [+ opcjonalny podpis] + _numericField + jednostka)`.
- Dodatkowo `_millDefaultRow:508` i `_defaultRow:615` — para o tym samym kształcie (`OperationType type, ...`), jedna dla mill, jedna dla lasera — wygląda na wariant tego samego rzędu „domyślne power/speed dla operacji” rozdzielony na dwie kopie zamiast jednego parametryzowanego builda.
- **Sugerowane podejście:** jeden parametryzowany builder `_settingsFieldRow({label, hint, controller, unit, decimal, isValid})`; rzędy redukują się do wywołań z innymi parametrami.
- **Ryzyko:** niskie, mechaniczna zmiana — zrobić po punkcie 10 (żeby `_numericField`/`_stepBtn` już korzystały ze wspólnych komponentów).
- **Rozmiar:** M.
- **Wynik:** dwie osobne unifikacje, bo to były dwie różne pary duplikatów:
  - `_numericSettingRow({label, ctrl, cs, width, decimal, hint, unit, isValid})` — jeden builder dla obu wariantów layoutu (z podpisem pod etykietą / bez), zastąpił 8 metod `_xxxRow`.
  - `_millDefaultRow`/`_defaultRow` **zostały jako osobne metody** (naprawdę różny kształt: dwa stepper-pola vs. slider+jedno pole — wymuszanie jednego builda byłoby sztuczne), ale wydzielone zostały ich faktycznie wspólne fragmenty: `_opTypeHeader(type, cs, bottomPadding:)` (kolorowy nagłówek nazwy operacji) i `_steppedNumberField(...)` (para `IconStepperButton` + `TextField` + opcjonalna jednostka, użyta 3×: spindle, feed, speed).
  - Przy okazji: `_defaultRow`'s pole speed miało **osobno wpisaną, identyczną kopię** `_compactFieldDecoration` zamiast jej użyć — scalone przy tej samej zmianie.

---

## P3 — Duplikacja stanu w `HomeScreen` (i realny bug, który stąd wynika)

### 12. Trzy równoległe „tryby testowe” (Focus/Kerf/Spot) jako osobne trójki pól zamiast jednego stanu ✅ zrobione
- `lib/screens/home/home_screen.dart` ma dla każdego z trzech testów osobny komplet: `_showXTest` / `_xTestConfig` / `_xTestDocument`, oraz lustrzany zestaw handlerów `_onXTest` / `_onXTestChanged` / `_onCloseXTest` / `_startXTestJob` / `_buildXTestDocument` — 3× to samo z inną nazwą.
- `lib/widgets/left_panel.dart` powiela dokładnie ten sam potrójny zestaw propsów (`showFocusTest`/`showKerfTest`/`showSpotTest` + config + callbacki po 4 na test).
- **Znaleziony realny bug wynikający z tej duplikacji:** `_onFocusTest` (`home_screen.dart:237`) resetuje tylko `_showKerfTest = false`, a `_onKerfTest` (`home_screen.dart:300`) resetuje tylko `_showFocusTest = false` — **żadna z tych dwóch metod nie zeruje `_showSpotTest`**. Tylko `_onSpotTest` (`:363`) zeruje oba pozostałe poprawnie. Da się więc wejść w stan, w którym np. `_showFocusTest` i `_showSpotTest` są jednocześnie `true` (sekwencja: otwórz Spot Test → otwórz Focus Test). Dziś to „ratuje" przypadkowo kolejność sprawdzania `if/else if` w `LeftPanel.build()` (`left_panel.dart:102-126`, sprawdza `showFocusTest` przed `showKerfTest` przed `showSpotTest`) — czyli działa, ale przez przypadek, nie przez projekt.
- **Sugerowane podejście:** jeden `enum TestMode { none, focus, kerf, spot }` + jeden generyczny kontener (np. `class TestSession<TConfig> { TConfig config; SvgDocument? document; }`) zamiast 3×3 pól. Eliminuje całą klasę błędów „zapomniałem zresetować trzecią flagę” i skraca `HomeScreen`/`LeftPanel`.
- **Ryzyko:** średnie — zmiana przepływu stanu w centralnym ekranie. Zrobić **po** punkcie 9 (gdy widgety testowe są już ujednolicone) i przetestować ręcznie przełączanie między wszystkimi trzema testami.
- **Rozmiar:** M.
- **Wynik:** zamiast `enum` + generycznego kontenera, użyta idiomatyczna dla Dart 3 `sealed class TestSession` (`lib/models/test_session.dart`) z wariantami `NoTestSession`/`FocusTestSession`/`KerfTestSession`/`SpotTestSession`, każdy niosący własny `config`+`document`. To silniejsza gwarancja niż enum+kontener: kompilator (exhaustive `switch`) wymusza obsłużenie każdego wariantu wszędzie, gdzie `TestSession` jest odczytywany — więc "dwa tryby aktywne naraz" jest teraz niereprezentowalne w typie, nie tylko "poprawnie zresetowane". `HomeScreen` ma jedno pole `_testSession` zamiast 9, jeden `_onCloseTest`/`_startTestJob` (switch po wariancie) zamiast 3×`_onCloseXTest`/3×`_startXTestJob`, i podwójny ternary-chain w `build()` zwinięty do jednego switcha + `previewDocument`. `LeftPanel` analogicznie. Świadomie zachowana różnica: `_onSpotTestChanged` nie przebudowuje dokumentu (geometria nie zależy od configu), Focus/Kerf owszem — udokumentowane komentarzem.

---

## P4 — Boilerplate w modelach (do przedyskutowania, mniejszy priorytet) ⏸ decyzja: bez zmian

**Decyzja (2026-08-22):** zostajemy przy opcji B — ręczny `copyWith`/`toMap`/`fromMap`, bez `freezed`/code-genu i bez dodatkowych testów regresyjnych na razie. Projekt jednoosobowy, koszt wprowadzenia nowej zależności buildowej (`build_runner`) uznany za nieuzasadniony względem 2 dotkniętych klas. Nie ruszać ponownie bez nowej rozmowy.

### 13. Ręcznie pisany `copyWith` w 6 modelach, część bardzo rozbudowana
- `MachineSettings` (`lib/models/machine_settings.dart`) ma **22 pola** i 22-parametrowy `copyWith`; podobny wzorzec (mniejszej skali) mają `LayerSettings`, `FocusTestConfig`, `KerfTestConfig`, `SpotTestConfig`.
- To nie jest błąd, ale przy każdym nowym polu trzeba ręcznie zsynchronizować 4 miejsca: definicję pola, parametr konstruktora, parametr `copyWith`, linijkę w ciele `copyWith`.
- **Sugerowane podejście (decyzja architektoniczna — nie robić bez rozmowy):** rozważyć `freezed`/code-gen dla tych 5-6 klas — `copyWith`/`==`/`hashCode` za darmo, bez ręcznej synchronizacji. Wprowadza jednak zależność od `build_runner` do procesu budowania, co jest zmianą stacku, nie tylko refaktorem kodu.
- **Rozmiar:** L (jeśli code-gen), albo pominąć.

### 14. Niespójna mutowalność modeli
- `LayerSettings` ma `copyWith` (styl „immutable + swap całości”) i faktycznie jest tak używana (`node.settings = settings` w `home_screen.dart:426`) — spójne.
- `SvgNode` natomiast jest mutowany polami bezpośrednio z zewnątrz (`node.enabled = !node.enabled;`, `node.selected = true;` w `home_screen.dart`) — brak `copyWith`, model traktowany jak zwykły mutowalny struct.
- Nie wymaga natychmiastowej zmiany (działa poprawnie z `setState`), ale warto docelowo ujednolicić konwencję: albo wszystkie modele jawnie mutowalne, albo wszystkie immutable+copyWith. Do decyzji przy okazji punktu 13.
- **Rozmiar:** S (jako decyzja konwencji), M (jako wykonanie).

---

## P5 — Duże pliki / SRP

### 15. `machine_settings_dialog.dart` (940 linii, jedna klasa `_MachineSettingsDialogState`)
- 16 pól `TextEditingController` inicjalizowanych ręcznie w `initState` (linie 34-53, 65-84), do zweryfikowania czy `dispose()` zwalnia je wszystkie 1:1; plus walidacja (`_parsePositiveInt`/`_parsePositiveDouble`) i budowa UI dla lasera **i** mill w jednej klasie.
- **Sugerowane podejście:** rozbić na mniejsze widgety per sekcja (np. `_LaserSettingsSection`, `_MillSettingsSection`, `_ConnectionSection`) — analogicznie do już nieźle podzielonego `layer_settings_panel.dart` (9 osobnych klas w jednym pliku, patrz punkt 10). Zrobić **po** punkcie 11 (ujednolicenie `_xxxRow`), żeby nie dublować pracy.
- **Ryzyko:** średnie, duży plik — dzielić sekcja po sekcji, commit po commicie.
- **Rozmiar:** L.

### 16. `home_screen.dart` (574 linii) jako „God widget”
- Odpowiada jednocześnie za: cykl życia połączenia GRBL (mock/serial swap), operacje na plikach, trzy tryby testowe (patrz P3), nawigację po drzewie węzłów, obsługę klawiatury (jog). Dużo odpowiedzialności w jednej klasie `State`.
- **Sugerowane podejście:** nie rozbijać na siłę. Po punkcie 12 (`TestMode` enum) i ewentualnym wydzieleniu logiki połączenia do osobnego kontrolera (np. `ConnectionController extends ChangeNotifier`) plik naturalnie się skróci.
- **Priorytet niski** — dziś nie powoduje duplikacji ani bugów, tylko rozmiar.
- **Rozmiar:** L, ale odłożone do czasu po P3.

---

## P6 — Spójność nazewnictwa (przy okazji innych punktów, nie osobna sesja)

### 17. Ta sama koncepcja „małego przycisku z ikoną” nazywana inaczej wszędzie ✅ zrobione
`_btn`, `_speedBtn`, `_stepBtn`, `_iconBtn`, `_CmdBtn`, `_JogBtn` — po wydzieleniu wspólnego widgetu (punkt 10) większość z tych nazw zniknie naturalnie. To, co zostanie z uzasadnionych powodów kształtu/rozmiaru (np. `_JogBtn`/`_CmdBtn` w `jog_panel.dart` są większe i mają opcjonalny label), nazwać spójnie z resztą.
- **Wynik:** po punktach 9-11 automatycznie zniknęły `_btn` (layer_settings_panel), `_speedBtn` (test-panele), `_stepBtn` (machine_settings_dialog) — wszystkie zastąpione `IconStepperButton`. `run_panel.dart`'s `_iconBtn` już miało jasną nazwę — bez zmian. Osobno znaleziony, niepowiązany `_btn` w `svg_preview_widget.dart` (toolbar toggle z tooltipem, inna koncepcja wizualna — bez tła, aktywny/nieaktywny/disabled stan) — zostawiony bez zmian, bo to nie ta sama koncepcja co stepper, a nazwa jest prywatna dla klasy (zero realnej kolizji).
- `jog_panel.dart`: `_JogBtn` → `_JogIconButton`, `_CmdBtn` → `_JogCommandButton` (spójny prefiks `_Jog`, nazwy opisują różnicę kształtu). Przy okazji usunięty martwy kod: `_JogBtn` miało opcjonalny parametr `label`/nullable `icon` z gałęzią tekstową — potwierdzone grepem, że żadne z 7 wywołań nigdy nie przekazywało `label`, więc `icon` stał się `required` a gałąź tekstowa usunięta.

### 18. `GrblService` miesza kilka odpowiedzialności w jednej abstrakcyjnej klasie bazowej ✅ zrobione
`lib/services/grbl_service.dart` łączy: log komunikacji (`commLog`/`logTx`/`logRx`), stan maszyny (`x`/`y`/`z`/`status`/`step`), stan joba (`jobProgress`/...) i `countJobSteps` (logika domenowa nad drzewem SVG — patrz punkt 3). To nie duplikacja, ale mieszanie 4 różnych odpowiedzialności w jednym bazowym typie (SRP). Dziś nie boli (tylko 2 implementacje: mock i serial), więc **niski priorytet** — rozważyć przy większym refaktorze warstwy `grbl`, nie teraz.
- **Wynik:** wydzielone 4 osobne klasy, każda z jedną odpowiedzialnością: `CommLog` (`lib/services/comm_log.dart` — log + `LogEntry`, capping do 500 wpisów), `MachineState` (`lib/models/machine_state.dart` — `x`/`y`/`z`/`status`/`stepMm`/`stepMmZ`/`connected`, plus przeniesiony tu `MachineStatus`/`MachineStatusDisplay`), `JobState` (`lib/models/job_state.dart` — `progress`/`currentStep`/`currentLabel`) i wolna funkcja `countJobSteps` (`lib/services/job_step_counter.dart` — czysta logika domenowa nad drzewem SVG, bez zależności od stanu instancji, więc bez sensu trzymać ją jako metodę serwisu).
  - `GrblService` stał się cienkim koordynatorem: komponuje te 4 klasy i **przekazuje dostęp przez identyczne, płaskie gettery/settery** (`x`, `y`, `z`, `status`, `stepMm`, `stepMmZ`, `connected`, `jobProgress`, `jobCurrentStep`, `jobCurrentLabel`, `commLog`, `logTx`/`logRx`) — bez logiki poza czystym forwardingiem.
  - **Świadoma decyzja co do zakresu:** zamiast przepisywać ~34 miejsca w UI (`right_panel`, `position_panel`, `code_panel`, `jog_panel`, `run_panel`, `machine_settings_dialog`, `home_screen`) na dostęp przez zagnieżdżone obiekty (np. `grbl.machine.x`), zachowany został płaski fasadowy interfejs — więc te pliki (poza `run_panel.dart`) **w ogóle się nie zmieniły**, tak samo `GrblMockService`/`GrblSerialService`, które nadal mutują `x`/`status`/`jobProgress`/... jak wcześniej (dziedziczone settery). Realny podział stanu i logiki (capping logu, posiadanie pól) i tak trafił do 4 osobnych klas — fasada eliminuje tylko zbędne ryzyko mechanicznego, ~30-plikowego przepisania bez dodatkowej korzyści. `MachineStatus`/`MachineStatusDisplay`/`LogEntry` re-eksportowane z `grbl_service.dart`, więc importy w reszcie apki też się nie zmieniły.
  - Jedyna realna zmiana wywołania: `run_panel.dart` woła teraz wolną funkcję `countJobSteps(roots)` zamiast `service.countJobSteps(roots)` — jedyne miejsce użycia tej metody w całym repo.
- **Weryfikacja:** `flutter analyze` czyste; `flutter test` bez nowych regresji (ten sam pre-istniejący overflow w `right_panel.dart` co na `master` bez zmian, potwierdzone przez `git stash`). Throwaway test sprawdzający forwarding (mutacje `x`/`y`/`z`/`status`, `jobProgress`/`jobCurrentStep`/`jobCurrentLabel`, `notifyListeners` przy `setMachineStatus`, capping logu do 500 wpisów i poprawność flagi `rx`/`tx`) — zielony, usunięty po weryfikacji.

---

## Podsumowanie / rekomendowana kolejność realizacji

1. ~~**P0 (1-2)** — usunięcie ~490 linii martwego kodu.~~ ✅
2. ~~**P2 punkt 10** (`IconStepperButton`) i **punkt 9** (test panels).~~ ✅
3. ~~**P1 punkty 4-7** (małe, niskoryzykowne duplikacje w `services`).~~ ✅
4. ~~**P1 punkt 3** (`svg_node_walker`).~~ ✅ — zweryfikowane bajt-identycznym G-code/bounds/toolpath przed/po (patrz punkt 3 wyżej).
5. ~~**P1 punkt 8** (`SettingsService` → `toMap`/`fromMap`).~~ ✅
6. ~~**P3 punkt 12** (`TestSession`).~~ ✅ — naprawiło przy okazji realny bug z podwójnie aktywnym trybem testowym.
7. **P2 punkt 11**, **P5 (15-16)** i **P4 (13-14)** — pozostają do dyskusji per punkt, mogą być rozdzielone na osobne sesje; P4 wymaga decyzji o wprowadzeniu code-genu, więc nie ruszać bez wcześniejszej rozmowy.
8. ~~**P6** — porządkujemy nazewnictwo przy okazji punktów, które i tak dotykają danych plików.~~ ✅ — punkt 17 przy okazji punktów 9-11, punkt 18 zrobiony osobno na wyraźną prośbę (2026-08-22), mimo dopisku "nie teraz" w opisie.

**Cały P0, P1, P2 punkty 9-10, P3 i P6 zrealizowane.** Zostało: P2 punkt 11 (`machine_settings_dialog.dart` — ujednolicenie `_xxxRow`), P4 (boilerplate modeli — decyzja o code-genie), P5 (duże pliki — `machine_settings_dialog.dart`, `home_screen.dart`).
