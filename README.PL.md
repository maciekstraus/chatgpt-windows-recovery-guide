# ChatGPT Desktop w Windows: awarie MessagePort i utrata dostępu do Chrome

[English version](README.md) | [Raport techniczny](BUG-REPORT.md) | [Zgłoszenie OpenAI #63610](https://github.com/openai/codex/issues/63610)

**Maciej Straus (@maciekstraus), 24 listopada 2026 r.** Niezależne studium przypadku z jednego komputera. Nie jest to oficjalna naprawa OpenAI.

## Najważniejszy wynik

Wersja **26.1117.3838.0** przywróciła obsługę dużych załączników i dostęp do Chrome w nowych rozmowach Work, także w istniejącym projekcie. Runtime i rozszerzenie Chrome pozostały niezmienione podczas testów zmiany wersji. Niektóre stare rozmowy nadal nie działały. Najpierw wypróbuj nowy czat Work, nie cofaj sprawnie działającej aplikacji.

## Objawy i diagnostyka

Aplikacja wyświetlała `A JavaScript error occurred in the main process` oraz `Error: Peer closed MessagePort connection`. Restart, naprawa, reset po zabezpieczeniu danych i aktualizacja nie rozwiązały problemu. Nowa rozmowa również uległa awarii podczas pracy z paczką zdjęć ok. 209 MB. Kilka dni wcześniej paczki 500 MB–1 GB działały.

W logu dotyczącym jednej istniejącej sesji wystąpiły:

```text
RangeError: Message exceeds the 536870912-byte serialization limit
MessagePortMain.postMessageWithSizeLimit (node:electron/js2c/utility_init:2:964)
```

Plik JSONL tej sesji miał ok. 344 MiB. Limit serializacji 512 MiB nie jest udowodnionym limitem rozmiaru załączników; przyczyny osobnej awarii świeżej rozmowy nie ustalono.

## Środowisko i porównanie wersji

Windows 11 Pro 26H2, kompilacja 26300.10075, x64; PowerShell 5.1; Chrome 157.0.8103.79; rozszerzenie ChatGPT 1.26.1120.11331; Runtime 26.1123.915.0 w trakcie testów zmiany wersji.

| Wersja aplikacji | Duże załączniki | Chrome w Work |
|---|---|---|
| 26.1120.5083.0 | Awarie | Nie testowano niezależnie |
| 26.1117.4957.0 | Awarie | Nie testowano niezależnie |
| 26.1111.9664.0 | Działały w nowym czacie (21 zdjęć) | Błąd w testowanej sesji |
| **26.1117.3838.0** | **Działały** | **Działał w nowych rozmowach Work, także w istniejącym projekcie** |

W starej rozmowie nadal występował błąd `Browser access requires the originating browser context`. Panel rozszerzenia Chrome potrafił odczytać bieżącą stronę. Po zmianie wersji nowa rozmowa desktopowa odczytała 13 kart; kolejna, wewnątrz istniejącego projektu, uzyskała dostęp do zalogowanego CMS, plików lokalnych i odzyskanych materiałów. Nie potwierdzono przyczyny źródłowej ani naprawy wszystkich historycznych sesji.

## Procedura odzyskiwania sprawności

> **Uwaga:** starsza wersja może mieć podatności i problemy z kompatybilnością danych. To tymczasowe obejście, nie uniwersalna naprawa. Najpierw skorzystaj ze wspieranych metod; na sprzęcie zarządzanym uzyskaj zgodę IT. Nie wyłączaj weryfikacji podpisu i nie usuwaj lokalnych rozmów.

### 1. Sprawdź wersje

```powershell
Get-AppxPackage *OpenAI* | Select-Object Name, Version, Status
```

Historia wdrożeń (w razie potrzeby PowerShell jako administrator):

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-AppXDeploymentServer/Operational'
    StartTime = (Get-Date).AddDays(-14)
} | Where-Object { $_.Message -match 'OpenAI\.Codex' } |
    Select-Object TimeCreated, Id, Message
```

Wpisy mogą dotyczyć zarówno instalowania, jak i usuwania pakietów. Na badanym komputerze logi znajdowały się m.in. pod `%LOCALAPPDATA%\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs`. Nie publikuj surowych logów.

### 2. Wykonaj kopie zapasowe

Zakończ zadania i zamknij aplikację. Wykonaj oddzielne prywatne kopie `%USERPROFILE%\.codex`, odpowiednich katalogów pakietów OpenAI pod `%LOCALAPPDATA%\Packages` oraz zewnętrznych folderów projektowych. Sprawdź błędy kopiowania i integralność ważnych plików. W naszym przypadku główny katalog .codex skopiowano poprawnie; niektóre zablokowane pliki systemowe pakietu pominięto. Nie jest to gwarancja pełnego odtworzenia środowiska. Nie używaj destrukcyjnego mirroringu, nie kasuj oryginałów, nie zakładaj pełnej synchronizacji chmurowej.

### 3. Pobierz i zweryfikuj podpisany pakiet

Poniższy wersjonowany adres dystrybucyjny producenta działał 24 listopada 2026 r. Dostępność może ulec zmianie. Nie pobieraj pakietów z nieznanych serwisów.

```powershell
$v = '26.1117.3838.0'
$file = Join-Path $env:USERPROFILE "Downloads\ChatGPT-$v.msix"
curl.exe -f -L "https://persistent.oaistatic.com/codex-app-prod/releases/$v/ChatGPT-x64.msix" -o $file
if ($LASTEXITCODE -ne 0) { throw 'Download failed' }
Get-Item $file | Select-Object Name, Length
$sig = Get-AuthenticodeSignature $file
$sig | Format-List Status, StatusMessage, SignerCertificate
if ($sig.Status -ne 'Valid') { throw 'Invalid or untrusted signature' }
Get-AppxPackage OpenAI.Codex | Format-List Name, Publisher, PackageFamilyName, Version
```

Zaobserwowany rozmiar: **811237227 bajtów**. Podpis: Valid. Podmiot podpisujący był zgodny z wydawcą zainstalowanego pakietu: `CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B`, wystawca Microsoft Marketplace CA G 028. Jeżeli podpis lub tożsamość pakietu są niezgodne, przerwij. Prawidłowy podpis nie gwarantuje bezpieczeństwa starej wersji.

Odczytaj manifest bez wypakowywania całego pakietu:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($file)
try {
    $reader = New-Object IO.StreamReader($zip.GetEntry('AppxManifest.xml').Open())
    try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $manifest.Package.Identity | Format-List Name, Version, Publisher, ProcessorArchitecture
    $manifest.Package.Dependencies.OuterXml
} finally { $zip.Dispose() }
```

Oczekiwana tożsamość: OpenAI.Codex, wersja 26.1117.3838.0, x64, zgodny wydawca. Manifest nie deklarował konkretnego pakietu Runtime, co nie gwarantuje jego kompatybilności.

### 4. Zainstaluj dopiero po zabezpieczeniu danych

Pierwsza próba instalacji wcześniejszej wersji zwróciła 0x80073D02 (pakiet w użyciu). Po zapisaniu pracy zadziałało poniższe polecenie. Przełącznik wymusza zakończenie aplikacji; może przerwać aktywne zadania. Nie było potrzeby odinstalowania.

```powershell
Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ForceTargetApplicationShutdown -ErrorAction Stop
Get-AppxPackage *OpenAI* | Select-Object Name, Version, Status
```

[Dokumentacja Microsoft: Add-AppxPackage](https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windows-11). Nie zmieniaj Runtime, rejestracji natywnego hosta ani uprawnień Chrome tylko po to, aby odtworzyć tę konfigurację.

### 5. Przetestuj w nowej rozmowie Work

1. Utwórz nowy czat Work na komputerze i wybierz integrację Chrome. Poproś o listę kart lub odczyt niesensytywnej strony bez dokonywania zmian.
2. Powtórz test wewnątrz istniejącego projektu. Sprawdź małą, a następnie większą paczkę niepoufnych plików.
3. Ponownie sprawdź wersję. Jeżeli błąd dotyczy tylko starej rozmowy, zachowaj ją, a zadanie przenieś z wykorzystaniem pliku przekazania i gotowych materiałów.
4. W naszym przypadku tymczasowo ustawiono politykę Microsoft Store AutoDownload=2. Dotyczy ona aplikacji Store szerzej, nie tylko ChatGPT, i nie gwarantuje zablokowania niezależnych aktualizacji OpenAI. Przywróć wcześniejsze ustawienie po zakończeniu testów lub po wydaniu stabilnej wspieranej wersji. Nie blokuj trwale aktualizacji bezpieczeństwa.

## Odzyskiwanie historii i prywatność

Część historycznych rozmów nadal nie ładowała się. Z prywatnej kopii jednej sesji JSONL odzyskano część tekstu, czytając rekordy bez modyfikacji oryginału i pomijając rekordy nadmiernej wielkości. Nie jest to pełne odtworzenie rozmowy w aplikacji. Kopie mogą zawierać treści rozmów, dane uwierzytelniające, obrazy, odpowiedzi narzędzi i dane firmowe. Nigdy nie publikuj katalogu .codex, profilu przeglądarki ani surowych logów.

## Powiązane zgłoszenia

- [#63610 — nasze zgłoszenie](https://github.com/openai/codex/issues/63610)
- [#63011](https://github.com/openai/codex/issues/63011) — załączniki obrazów w Windows i MessagePort.
- [#62793](https://github.com/openai/codex/issues/62793), [#62170](https://github.com/openai/codex/issues/62170) — limit serializacji 512 MiB na macOS.
- [#57491](https://github.com/openai/codex/issues/57491), [#57523](https://github.com/openai/codex/issues/57523) — błędy kontekstu przeglądarki.

Warto zbadać stronicowanie historii, obsługę błędów serializacji bez zamykania połączenia oraz wiązanie kontekstu przeglądarki z sesją Work. To pojedyncze studium przypadku, nie zalecenie instalowania starszej wersji na każdym komputerze.
