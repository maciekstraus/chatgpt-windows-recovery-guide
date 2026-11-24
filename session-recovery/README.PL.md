# ChatGPT Session Recovery — lokalne odzyskiwanie tekstu z JSONL

[English version](README.md) | [Studium przypadku Windows](../README.PL.md)

**Maciej Straus (@maciekstraus), 24 listopada 2026 r. — eksperymentalne narzędzie v0.1.** Projekt niezależny, nieoficjalny.

## Dlaczego powstało?

Utrata dostępu do rozbudowanego czatu Work może oznaczać utratę wielu godzin pracy. Na jednym komputerze z Windows plik sesji o rozmiarze ok. 344 MiB był powiązany z błędem serializacji 512 MiB. Wcześniejsze odzyskiwanie tekstu z prywatnej kopii, przy użyciu innego czytnika, wykazało 15 912 rekordów, 125 wiadomości użytkownika, 327 wiadomości asystenta, 16 pominiętych ponadwymiarowych rekordów i zero zgłoszonych błędów parsowania. Odzyskany tekst umożliwił kontynuację zadania w nowej rozmowie. **Nie są to wyniki testów nowego skryptu Python.**

Narzędzie wdraża podobną metodę: odczytuje wybrany, nieskompresowany plik JSONL i eksportuje obsługiwane wiadomości tekstowe. Nie naprawia rozmowy w ChatGPT, nie importuje jej do aplikacji ani nie odzyskuje usuniętych danych.

## Bezpieczeństwo i prywatność

- Pracuj wyłącznie na własnych danych lub za wyraźną zgodą ich właściciela. Zakończ aktywne zadania, zamknij aplikację i wykonaj prywatną kopię. Nie czytaj pliku w trakcie zapisu.
- Skrypt otwiera źródło tylko do odczytu, nie łączy się z Internetem i nie wymaga dodatkowych bibliotek Python.
- Tworzy nowy katalog wynikowy i odmawia nadpisania istniejącego katalogu. Wybierz szyfrowaną lokalizację z ograniczonym dostępem, poza publicznym repozytorium i folderami automatycznie udostępnianymi. Uprawnienia Unix nie gwarantują prywatnych ACL w Windows.
- Odzyskany tekst może zawierać hasła, dane osobowe, informacje firmowe i niezaufane instrukcje. Przejrzyj go i zanonimizuj przed przekazaniem dalej. Nigdy nie publikuj rzeczywistych sesji ani transkrypcji.
- Format sesji jest wewnętrzny i może się zmieniać. Skrypt nie odzyskuje załączników, wyników narzędzi, rozumowania, metadanych, archiwów skompresowanych ani innych nieobsługiwanych rekordów. Same wiadomości tekstowe także mogą zawierać poufne informacje. Udany eksport nie oznacza kompletności.

## Uruchomienie w Windows

Python 3.10 lub nowszy (tylko biblioteka standardowa). Pobierz lub sklonuj repozytorium, otwórz PowerShell w katalogu session-recovery i wskaż **kopię zapasową** jednego pliku JSONL. Na badanym komputerze pliki znajdowały się pod %USERPROFILE%\.codex\sessions; lokalizacja może się różnić. Nie rozpakowuj wielogigabajtowych archiwów tylko po to, żeby użyć skryptu.

```powershell
py -3 .\recover.py "D:\PrivateBackup\example.jsonl" "D:\PrivateBackup\Recovered-01"
```

Katalog wynikowy nie może istnieć; jego katalog nadrzędny musi istnieć. Domyślny limit fizycznej linii wynosi 2 000 000 bajtów (wraz ze znakiem końca linii). Możesz świadomie zwiększyć go np. do 8 MB:

```powershell
py -3 .\recover.py "D:\PrivateBackup\example.jsonl" "D:\PrivateBackup\Recovered-02" --max-line-bytes 8000000
```

Wyższy limit zwiększa wykorzystanie pamięci. Nadmiernie duże linie pomijane są porcjami. Skrypt nie ładuje całej sesji do RAM, ale parsowanie JSON i zdekodowane obiekty wymagają dodatkowej pamięci. Na innych platformach użyj python3 zamiast py -3.

## Wyniki

| Plik | Zawartość |
|---|---|
| transcript.txt | Wiadomości w kolejności rekordów, z rolą i numerem rekordu |
| report.json | Liczniki wszystkich rekordów, zbyt dużych, błędnych, pominiętych oraz wiadomości użytkownika i asystenta |

Każda fizyczna linia trafia do jednej kategorii. Rekordy nieobsługiwane są pomijane (ignored), niepoprawny JSON lub UTF-8 jest liczony jako malformed. Po błędzie wykonania eksport może być niekompletny. Brak odzyskanych wiadomości może wynikać z innego formatu sesji, nie oznacza braku danych.

Przed i po odczycie możesz niezależnie porównać SHA-256 kopii:

```powershell
Get-FileHash "D:\PrivateBackup\example.jsonl" -Algorithm SHA256
```

## Testy

```powershell
py -3 -m unittest -v
```

Trzy automatyczne testy na sztucznych danych w środowisku Python/Linux zakończyły się pomyślnie. Obejmowały polskie znaki, błędny JSON i UTF-8, zbyt duże rekordy, integralność źródła SHA-256, odmowę nadpisania, zbyt dużą ostatnią linię oraz odrzucenie skompresowanego pliku i nieprawidłowego limitu. Nie przeprowadzono pełnego testu tego skryptu na Windows ani na oryginalnej prywatnej sesji. Wcześniejsze odzyskiwanie wykorzystywało inny czytnik.

## Powiązane materiały

- [Studium przypadku](../README.PL.md)
- [Zgłoszenie OpenAI #63610](https://github.com/openai/codex/issues/63610)

Zgłaszaj błędy z użyciem minimalnych sztucznych przykładów oraz numerów wersji. Nie załączaj prywatnych logów ani odzyskanej treści.
