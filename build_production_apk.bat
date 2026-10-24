@echo off
setlocal
echo ========================================================
echo   Generation de l'APK de Production - LoueMoi
echo   Environnement: Production (https://transfert-online.site)
echo ========================================================
echo.

cd /d "%~dp0"

echo [1/3] Nettoyage rapide et recuperation des dependances...
call flutter pub get

echo.
echo [2/3] Compilation de l'APK Release Production...
call flutter build apk --release --dart-define=ENV=production --dart-define=API_BASE_URL=https://transfert-online.site

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] La compilation a echoue. Verifiez les logs ci-dessus.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Copie de l'APK a la racine du projet...
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "LoueMoi-release.apk"

echo.
echo ========================================================
echo   SUCCES ! L'APK de production est pret :
echo   Fichier: %~dp0LoueMoi-release.apk
echo ========================================================
echo.
pause

