# Prompt: Wygeneruj gdtuner — standalone Godot 4 addon

Uruchom w Claude Code w NOWYM, pustym katalogu dla repo `gdtuner`.

---

## Prompt do wklejenia:

```
Stwórz reużywalny, standalone addon Godot 4 o nazwie `gdtuner` — narzędzie deweloperskie do live-tuningu parametrów gry przez osobne okno z kontrolkami. Addon jest osobnym repo/paczką, instalowaną w dowolnym projekcie Godot 4.

---

## STRUKTURA REPO

```
gdtuner/
├── README.md                        # dokumentacja + przykłady użycia
├── LICENSE                          # MIT
├── addons/gdtuner/
│   ├── plugin.cfg
│   ├── plugin.gd                    # EditorPlugin — rejestruje autoload + self-install
│   ├── debug_tuner.gd               # AUTOLOAD — centralny manager, okno, registry
│   ├── tunable_registrar.gd         # Node do wrzucenia jako dziecko sceny
│   ├── installer.gd                 # GDScript tool script — self-install logic
│   └── controls/                    # klasy budujące UI kontrolek
│       ├── tuner_slider.gd
│       ├── tuner_checkbox.gd
│       ├── tuner_color.gd
│       ├── tuner_dropdown.gd
│       ├── tuner_vector.gd
│       └── tuner_button.gd
└── example/                         # minimalny projekt-przykład
    ├── project.godot
    └── main.tscn                    # scena z przykładowym TunableRegistrar
```

---

## SYSTEM INSTALACJI

### Self-installing plugin

Addon instaluje się w docelowym projekcie przez GDScript tool script. User flow:

1. Klonuje/pobiera repo gdtuner
2. W swoim projekcie Godot uruchamia z menu: `Project → Tools → Install gdtuner`
   LUB kopiuje folder `addons/gdtuner/` ręcznie do swojego projektu
3. Włącza plugin w `Project → Project Settings → Plugins`
4. Plugin automatycznie:
   - Rejestruje `DebugTuner` jako autoload
   - Dodaje `TunableRegistrar` do listy dostępnych Node'ów

### plugin.gd (EditorPlugin):

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
    # Rejestruj autoload
    add_autoload_singleton("DebugTuner", "res://addons/gdtuner/debug_tuner.gd")
    # Rejestruj custom node type
    add_custom_type("TunableRegistrar", "Node",
        preload("res://addons/gdtuner/tunable_registrar.gd"),
        preload("res://addons/gdtuner/icon.svg") # mała ikonka narzędzia
    )

func _exit_tree() -> void:
    remove_autoload_singleton("DebugTuner")
    remove_custom_type("TunableRegistrar")
```

### installer.gd (opcjonalny tool script do instalacji z zewnątrz):

Tool script który można uruchomić z CLI żeby skopiować addon do projektu:

```bash
# Z poziomu terminala (np. w Claude Code workflow)
cd /path/to/my-game
cp -r /path/to/gdtuner/addons/gdtuner addons/gdtuner
# Potem włącz plugin w edytorze lub:
godot --headless --script addons/gdtuner/installer.gd
```

installer.gd:
- Sprawdza czy `addons/gdtuner/` istnieje w bieżącym projekcie
- Modyfikuje `project.godot` — dodaje plugin do enabled plugins i autoload
- Wypisuje status instalacji do konsoli
- Działa w trybie `--headless` (ważne dla CI i Claude Code)

---

## ARCHITEKTURA ADDONU

### DebugTuner (autoload singleton)

Centralny manager. Odpowiada za:
- Tworzenie i zarządzanie osobnym `Window` z kontrolkami
- Przechowywanie wartości w `Dictionary` — klucze: `"sekcja_id/nazwa"`
- Emitowanie sygnałów przy zmianach
- API do odczytu wartości
- Logowanie zmian do konsoli w formacie parsowalnym
- Grupowanie kontrolek w składane sekcje
- Toggle okna klawiszem (domyślnie F12)
- TYLKO w debug buildach — w uprodukcji no-op, zero kosztu

```gdscript
# Publiczne API:

# Odczyt — bezpieczny, zwraca fallback jeśli klucz nie istnieje
func get_value(key: String, fallback: Variant = null) -> Variant

# Rejestracja — wołane przez TunableRegistrar, nie user
func register_section(section_id: String, display_name: String) -> void
func register_control(section_id: String, key: String, config: Dictionary) -> void
func unregister_section(section_id: String) -> void

# Sygnały
signal value_changed(key: String, value: Variant)
signal button_pressed(key: String)

# Toggle
func toggle_window() -> void

# Export bieżących wartości
func copy_all_values_to_clipboard() -> void
func get_all_values_as_string() -> String
```

### TunableRegistrar (custom Node type)

Node który użytkownik dodaje jako dziecko dowolnej sceny. W `_ready()` rejestruje kontrolki w DebugTuner, w `_exit_tree()` wyrejestrowuje — kontrolki żyją i umierają ze sceną.

```gdscript
class_name TunableRegistrar
extends Node

@export var section_name: String = ""
@export var section_id: String = ""  # auto-generated jeśli puste

# User override'uje tę metodę
func _register_tunables() -> void:
    pass

# API dostępne wewnątrz _register_tunables():
func add_float(key: String, min_val: float, max_val: float,
    default: float, step: float = 0.01) -> void
func add_int(key: String, min_val: int, max_val: int,
    default: int, step: int = 1) -> void
func add_bool(key: String, default: bool) -> void
func add_color(key: String, default: Color) -> void
func add_dropdown(key: String, options: Array[String],
    default_index: int = 0) -> void
func add_vector2(key: String, default: Vector2,
    min_val: Vector2, max_val: Vector2, step: float = 1.0) -> void
func add_vector3(key: String, default: Vector3,
    min_val: Vector3, max_val: Vector3, step: float = 1.0) -> void
func add_button(key: String, label: String) -> void
```

---

## WYGLĄD OKNA

Window:
- Tytuł: "🎛 gdtuner"
- Rozmiar: 380x650
- Pozycja: prawy górny róg ekranu (50px offset)
- `unfocusable = true`, `always_on_top = true`
- Zamknięcie = hide (toggle F12)

Layout:
- `ScrollContainer` → `VBoxContainer`
- Sekcje jako składane grupy (klik na header = toggle dzieci)
- Header sekcji: pogrubiony label, lekko ciemniejsze tło
- Kontrolki: label po lewej, widget po prawej (HBoxContainer)
- Przycisk reset "↺" przy każdej kontrolce
- Na dole okna: przycisk "📋 Copy All Values"

### Kontrolki:

**Slider (float/int):**
Label z aktualną wartością + HSlider + reset. Emituje ciągle podczas przeciągania.

**Checkbox:**
Label + CheckBox + reset.

**Color:**
Label + ColorPickerButton (mały kwadrat z kolorem, klik otwiera picker) + reset.

**Dropdown:**
Label + OptionButton + reset.

**Vector2:**
Label + reset, pod spodem dwa slidery (x, y) z labelkami.

**Vector3:**
Label + reset, pod spodem trzy slidery (x, y, z) z labelkami.

**Button:**
Buttony w sekcji renderowane obok siebie w FlowContainer.

---

## CONSOLE OUTPUT

Każda zmiana loguje:
```
[gdtuner] section_id/key = value
```

Przykłady:
```
[gdtuner] torch/intensity = 1.35
[gdtuner] torch/color = Color(1, 0.8, 0.3, 1)
[gdtuner] gameplay/show_grid = true
[gdtuner] gameplay/difficulty = "Hard"
[gdtuner] player/offset = Vector2(12, -5)
```

Buttony:
```
[gdtuner:action] section_id/key pressed
```

### "Copy All Values" output:

```
# gdtuner values — 2025-01-15 14:32:07
torch/intensity = 1.35
torch/radius = 280.0
torch/color = Color(1, 0.8, 0.3, 1)
gameplay/move_speed = 0.15
gameplay/difficulty = "Hard"
player/offset = Vector2(12, -5)
```

---

## WYMAGANIA TECHNICZNE

1. Cały addon = no-op w uprodukcji. `get_value()` zwraca fallback, reszta nie procesuje. Zero kosztu.

2. `TunableRegistrar._exit_tree()` wyrejestrowuje sekcję — kontrolki znikają z okna.

3. Wielokrotne instancje: 10 torch'y z tym samym `section_id = "torch"` = 1 sekcja w tunerze, suwak wpływa na WSZYSTKIE. Wewnętrzny counter instancji — sekcja znika kiedy ostatnia instancja opuści drzewo.

4. Klucze: `"section_id/control_key"` — np. `"torch/intensity"`.

5. Kontrolki emitują W TRAKCIE przeciągania (nie po puszczeniu).

6. Reset "↺" przywraca default i emituje sygnał.

7. Window nie blokuje gry.

8. Addon musi działać na Godot 4.3+ (nie używaj API specyficznego dla 4.4+, chyba że z feature detection).

9. Brak zewnętrznych zależności — czysty GDScript, zero pluginów trzecich.

10. `section_id` auto-generowany z `section_name.to_snake_case()` jeśli pusty.

---

## README.md

Wygeneruj README z sekcjami:

### Installation
- Ręczna: skopiuj `addons/gdtuner/` do projektu, włącz plugin
- CLI: `cp -r` + `godot --headless --script`
- Pokaż oba sposoby

### Quick Start
Minimalny przykład — 3 kroki:
1. Stwórz skrypt dziedziczący po TunableRegistrar
2. Dodaj jako dziecko sceny
3. Odczytaj wartości w _process() lub przez sygnał

### API Reference
Wszystkie publiczne metody DebugTuner i TunableRegistrar z krótkimi opisami.

### Usage with Claude Code
Pokaż workflow:
1. Ustaw wartości suwakami
2. Kliknij "Copy All Values"
3. Wklej do Claude Code: "użyj tych wartości jako nowe defaulty"

### Controls Reference
Tabela: typ kontrolki → metoda → parametry → screenshot/opis wyglądu

---

## EXAMPLE PROJECT

W `example/` stwórz minimalny projekt Godot pokazujący użycie:
- Scena z Sprite2D + PointLight2D
- TunableRegistrar z kilkoma kontrolkami różnych typów
- Skrypt odczytujący wartości w _process()
- Wystarczający żeby otworzyć w edytorze i zobaczyć addon w akcji

---

## IMPLEMENTACJA

Wygeneruj WSZYSTKIE pliki. Kolejność:
1. plugin.cfg + plugin.gd
2. debug_tuner.gd (core)
3. controls/ (wszystkie 6 typów)
4. tunable_registrar.gd
5. installer.gd
6. README.md
7. LICENSE (MIT)
8. example/

Po wygenerowaniu:
1. Wylistuj wszystkie stworzone pliki
2. Pokaż jak zainstalować w istniejącym projekcie
3. Pokaż minimalny przykład użycia
```
