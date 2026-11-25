# ChatGPT Desktop Health Audit V2 (Windows)

[English version](README.md) | [Kod PowerShell](ChatGPT-Health-Audit-v2.ps1) | [Raport techniczny](../BUG-REPORT.md) | [Naprawa kolejki](../queue-recovery/README.PL.md)

**Niezależne narzędzie diagnostyczne tylko do odczytu, sprawdzone 25 listopada 2026 r. na jednym komputerze z Windows.** Nie jest oficjalnym narzędziem OpenAI ani gwarancją bezpieczeństwa we wszystkich wersjach. Nie wykonuje automatycznej naprawy, operacji sieciowych ani modyfikacji oryginalnych baz i historii.

## Uruchomienie

Windows PowerShell 5.1 x64, systemowa biblioteka winsqlite3.dll i odpowiednia ilość wolnej przestrzeni na tymczasową kopię największej bazy wraz z WAL. Zakończ zadania i całkowicie zamknij ChatGPT Desktop/Codex. Chrome może pozostać otwarty. Pobierz i przeczytaj kod. Na urządzeniu zarządzanym przestrzegaj polityki IT. Nie wyłączaj globalnej polityki wykonywania skryptów.

```powershell
$p = Join-Path $env:USERPROFILE 'Downloads\ChatGPT-Health-Audit-v2.ps1'
Get-FileHash -LiteralPath $p -Algorithm SHA256
& $p -Since (Get-Date).AddDays(-1)
```

SHA256 dokładnie opublikowanego, sprawdzonego pliku (UTF-8 BOM, LF): `6386d40dde2ece314e187618fb7232941d3d0ba37e6f81527977bee84e9d2ef9`.
Jeżeli system blokuje skrypty, skonsultuj administratora lub użyj zatwierdzonej metody uruchomienia. Na badanym komputerze wykorzystano jednorazową politykę dla procesu, nie zmieniano jej globalnie. Skrypt odmawia rozpoczęcia audytu po wykryciu procesów ChatGPT lub Codex.

## Zakres

- Wersje pakietów OpenAI, wolny dysk, rozmiary SQLite i WAL, strukturalny quick_check, strony wolne i zajęte.
- Liczba bajtów kolejki queued-follow-ups, szczegóły JSON z limitem diagnostycznym 64 MiB, osobna baza kolejki, główny JSON i kopia (tylko klucz najwyższego poziomu).
- Inwentaryzacja sesji, największe pliki, ograniczone próbki znaczników multimediów bez dekompresji sesji, lokalne katalogi i potencjalne dokumenty PDF.
- Ograniczone próbki końcówek logów; liczone są pasujące linie, a nie odrębne awarie.

Raporty powstaną w nowym katalogu AUDYT_CHATGPT_* na pulpicie. Przed udostępnieniem przeczytaj również zbiorczy 01_PODSUMOWANIE.txt. Pozostałe pliki zachowaj prywatnie: mogą zawierać tytuły, identyfikatory i ścieżki. Nie publikuj baz, surowych logów, załączników ani kopii. Tymczasowe kopie baz są poufne; zwykłe usunięcie pliku nie jest bezpiecznym wymazaniem.

## Walidacja praktyczna: 25 listopada 2026

| Pomiar | Przed drugą naprawą (22:42) | Po naprawie i 6 testach (22:54) |
|---|---:|---:|
| Kolejka globalna (bajty) | 274 205 978 | 2 |
| Wolne strony bazy ustawień | 4 690 | 71 701 |
| Przestrzeń do ponownego użycia (MiB) | 18,320 | 280,082 |
| quick_check | 7/7 OK | 7/7 OK |
| Ostrzeżenia | 1 | 0 |
| Pliki sesji | 1700 | 1701 |
| Rekordy historii | 81 956 | 81 965 |

Oba audyty zakończono na wersji 26.1117.3838.0 i Runtime 26.1123.915.0. Punktowa naprawa została wykonana oddzielnie; audyt nie naprawiał bazy. Po naprawie w trzech ostatnio zmienionych logach nie znaleziono dopasowań błędów od 22:48:52. To krótka, ograniczona obserwacja. Próba uruchomienia przy działającej aplikacji poprawnie została zablokowana. Użytkownik potwierdził 6 testów; nowa rozmowa Work, małe zdjęcie i dostęp do katalogu ze zdjęciami pozostały niewykonane. Wskaźniki zbiorcze nie dowodzą kompletnego zachowania danych ani synchronizacji.

## Ograniczenia

To audyt przy zamkniętej aplikacji, nie monitor działający na żywo. Kopie DB i WAL kontrolowane są według rozmiaru i czasu modyfikacji, nie stanowią atomowego backupu. Limit 64 MiB to zabezpieczenie diagnostyczne, nie limit produktu. Duże kolejki wymagają osobnego odczytu. Skrypt może zwrócić niepełne wyniki przy nietypowym schemacie lub zablokowanych plikach. Zero ostrzeżeń nie jest gwarancją pełnej sprawności. JSON badany jest tylko na najwyższym poziomie. Logi: maks. 30 ostatnio zmienionych plików, do 4 MiB końcówki każdego; bez zawartości bazy logów. Rozmiary sesji nie są rozmiarami RPC. PDF-y to potencjalne dokumenty, nie udowodnione załączniki projektu. Dane dostępne tylko w chmurze są poza zakresem. Nie usuwaj historii, WAL/SHM ani nie wykonuj VACUUM na podstawie raportu.

Jeśli można otworzyć problematyczną rozmowę, najpierw spróbuj anulować konkretną niewysłaną wiadomość w interfejsie, po potwierdzeniu, że można ją utracić. [Opis odzyskania sprawności przez UI na macOS](https://github.com/openai/codex/issues/63217#issuecomment-7163980390). W przeciwnym razie zabezpiecz kopię i rozważ [procedurę punktową](../queue-recovery/README.PL.md). Monitor ostrzegawczy i alternatywny workflow zdjęć są planowanymi, jeszcze niezwalidowanymi etapami.
