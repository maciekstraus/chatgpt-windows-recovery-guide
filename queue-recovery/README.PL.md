# Naprawa kolejki SQLite w Windows (nieoficjalna)

24 listopada 2026 r. — po punktowej korekcie na jednym komputerze z Windows użytkownik potwierdził 9/9 testów. Inspiracja: [diagnostyka macOS autorstwa Shinshin124](https://github.com/openai/codex/issues/63217#issuecomment-7128925968). [Raport techniczny](../BUG-REPORT.md) | [Zgłoszenie #63610](https://github.com/openai/codex/issues/63610).

## Aktualizacja — 25 listopada 2026 r.

W tej samej rozmowie na Windows powróciła jedna oczekująca wiadomość z obrazami (274 205 978 bajtów / 261,503 MiB). Świeża zweryfikowana kopia i punktowa transakcja ponownie przywróciły kolejkę do 2 bajtów. Sześć wykonanych testów zaliczono, trzy odłożono. [Health Audit V2](../health-audit/README.PL.md) potwierdził pustą kolejkę, 7/7 kontroli strukturalnych, zero ostrzeżeń i brak dopasowań błędów w krótkiej próbce logów. [Raport techniczny](../BUG-REPORT.md). Uogólniony skrypt naprawczy poniżej nadal nie był niezależnie testowany end-to-end; audyt jest odrębnym, praktycznie sprawdzonym narzędziem tylko do odczytu.

**Przed edycją SQLite:** gdy rozmowa jest dostępna, spróbuj anulować wyłącznie problematyczną niewysłaną wiadomość/szkic po potwierdzeniu, że można ją utracić. [CHUAN33 opisał naprawę w samym UI na macOS](https://github.com/openai/codex/issues/63217#issuecomment-7163980390). Sprawdź też oba globalne JSON-y: [#63592](https://github.com/openai/codex/issues/63592) opisuje inny przypadek Windows z danymi kolejki w obu plikach. Nie czyść wszystkich kolejek i nie resetuj całego profilu rutynowo. Nie potwierdzono trwałej naprawy.

## Wyniki

Aplikacja 26.1117.3838.0: wcześniejszy downgrade pomógł jedynie tymczasowo. W logach jednej sesji wystąpił limit serializacji 536870912 bajtów. Baza ustawień miała 281,89 MiB, kolejka queued-follow-ups 292 893 447 bajtów (279,325 MiB), jedna wiadomość i znacznik data:image/. Pełny identyfikator sesji był zgodny z wcześniejszym błędem. Symulacja bez zapisu dała 2 bajty. Po kopii zweryfikowanej SHA256 transakcja SQLite usunęła wyłącznie wpis tej sesji z kolejki. JSON poprawny, quick_check: ok, kopia bez zmian. Użytkownik potwierdził start, projekty i historię, pierwotną rozmowę, dwie kolejne wiadomości tekstowe, nowy Work, Chrome, jedno i kilka zdjęć. Nie zmieniano wersji podczas naprawy. Nie wykonywano VACUUM.

To obserwacja skutecznego odzyskania sprawności, nie dowód dokładnego mechanizmu RPC, uniwersalnej przyczyny ani trwałej naprawy.

## Instrukcja

Najpierw skorzystaj ze wspieranych metod i skonsultuj IT na urządzeniu zarządzanym. Zakończ zadania, zamknij ChatGPT Desktop i Codex, wykonaj pełną prywatną kopię historii, ustawień i projektów. Skrypt działa z Windows PowerShell 5.1 i winsqlite3.dll. Przeczytaj kod przed uruchomieniem. To uogólniona wersja procedury zastosowanej na badanym komputerze, **nie została niezależnie uruchomiona ani przetestowana end-to-end na Windows**. Nie kasuj plików WAL/SHM.

W katalogu pobranego skryptu uruchom:
```powershell
.\Recover-Queue.ps1
```
Domyślny audyt odczytuje tymczasową kopię, weryfikuje SHA256 i integralność; pokazuje rozmiary, identyfikatory, liczbę wiadomości i znacznik obrazów, nie treść. Nie publikuj identyfikatorów ani kopii.

Tylko jeśli jest jeden problematyczny wpis z jedną niewysłaną wiadomością i możesz ją utracić:
```powershell
.\Recover-Queue.ps1 -Repair -ThreadId '<wlasny GUID>' -ExpectedBytes <Total_bytes z audytu>
```
Zastąp oba symbole zastępcze. Skrypt zabezpiecza trwałą kopię i wymaga wpisania REMOVE ONE PENDING MESSAGE. Odmawia naprawy przy innej strukturze kolejki. Usuwa niewysłany tekst i załączniki z aktywnej kolejki, zachowując je w prywatnej kopii. Nie jest to bezpieczne wymazanie danych. Nie modyfikuje bazy historii rozmów. Błąd przed COMMIT oznacza wycofanie niezakończonej transakcji przy zamknięciu połączenia; błąd po COMMIT wymaga diagnostyki, nie powtarzania w ciemno. Przy odtwarzaniu kopii trzeba zamknąć aplikację i zabezpieczyć aktualną bazę wraz z WAL/SHM; pełne przywrócenie może nadpisać nowsze ustawienia.

Przetestuj start, historię, dwie kolejne wiadomości, nowy Work, odczyt strony w Chrome i małe niepoufne załączniki. Zachowaj kopię. Nie cofaj wersji tylko na podstawie tego opisu.

[English version](README.md)
