# Corriger le mojibake Windows-1252 dans tous les fichiers .dart
# et nettoyer les commentaires avec caracteres de dessin corrompus

$projects = @(
  'c:\flutter_application_2',
  'c:\allofoods_admin',
  'c:\allofoods_merchant',
  'c:\allofoods_driver'
)

# Table de remplacement mojibake -> caractere correct (UTF-8 lu comme cp1252)
$replacements = [ordered]@{
  # Caracteres francais minuscules
  'Ã©' = 'é'
  'Ã¨' = 'è'
  'Ã ' = 'à'
  'Ã§' = 'ç'
  'Ã®' = 'î'
  'Ã´' = 'ô'
  'Ã»' = 'û'
  'Ãª' = 'ê'
  'Ã¹' = 'ù'
  'Ã¯' = 'ï'
  'Ã¼' = 'ü'
  'Ã«' = 'ë'
  'Ã¢' = 'â'
  'Ã¶' = 'ö'
  'Ã±' = 'ñ'
  # Caracteres francais majuscules
  'Ã‰' = 'É'
  'Ã€' = 'À'
  'Ã‡' = 'Ç'
  'Ã"' = 'Ô'
  'ÃŽ' = 'Î'
  'Ãˆ' = 'È'
  'Ãš' = 'Ú'
  'Ã•' = 'Õ'
  # Ponctuation typographique (cp1252)
  'â€"' = '–'
  'â€™' = "'"
  'â€˜' = "'"
  'â€œ' = '"'
  'â€' = '"'
  'â€¦' = '…'
  'â€¢' = '•'
  # Emoji courants
  'âœ…' = '✅'
  'â†'' = '→'
  'â†'' = '←'
  # Espace insecable
  'Â ' = ' '
  'Â«' = '«'
  'Â»' = '»'
}

# Detecter si une ligne est un commentaire separateur corrompu
# (lignes avec beaucoup de caracteres U+2022 bullet ou U+00E2 â repetitifs)
function Is-GarbledSeparator($line) {
  if (-not ($line -match '^\s*//')) { return $false }
  $comment = $line -replace '^\s*//', ''
  # Compter les chars suspects (â U+00E2, • U+2022, " U+201C/201D, › etc.)
  $suspicious = ($comment.ToCharArray() | Where-Object {
    $cp = [int][char]$_
    ($cp -eq 0x00E2) -or ($cp -eq 0x2022) -or ($cp -eq 0x201C) -or ($cp -eq 0x201D) -or
    ($cp -eq 0x2018) -or ($cp -eq 0x2019) -or ($cp -eq 0x203A) -or ($cp -eq 0x2039) -or
    ($cp -ge 0x2500 -and $cp -le 0x257F)
  }).Count
  $total = $comment.Trim().Length
  if ($total -eq 0) { return $false }
  # Si plus de 30% des chars sont suspects -> separateur corrompu
  return ($suspicious / $total) -gt 0.30
}

$totalFixed = 0

foreach ($proj in $projects) {
  $libPath = Join-Path $proj 'lib'
  if (-not (Test-Path $libPath)) { continue }

  $files = Get-ChildItem -Path $libPath -Filter '*.dart' -Recurse
  foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.UTF8Encoding]::new($false))
    $original = $content

    # 1. Remplacer le mojibake dans les string literals et commentaires texte
    foreach ($kv in $replacements.GetEnumerator()) {
      $content = $content.Replace($kv.Key, $kv.Value)
    }

    # 2. Nettoyer les lignes de commentaires separateurs corrompus
    $lines = $content -split "`n"
    $newLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
      if (Is-GarbledSeparator $line) {
        # Extraire le texte utile entre les separateurs
        $comment = $line -replace '^\s*//', ''
        # Supprimer les chars suspects
        $sb = [System.Text.StringBuilder]::new()
        foreach ($c in $comment.ToCharArray()) {
          $cp = [int][char]$c
          $isSuspect = ($cp -eq 0x00E2) -or ($cp -eq 0x2022) -or
                       ($cp -eq 0x201C) -or ($cp -eq 0x201D) -or
                       ($cp -eq 0x2018) -or ($cp -eq 0x2019) -or
                       ($cp -eq 0x203A) -or ($cp -eq 0x2039) -or
                       ($cp -ge 0x2500 -and $cp -le 0x257F)
          if (-not $isSuspect) { $sb.Append($c) | Out-Null }
        }
        $text = $sb.ToString().Trim()
        $indent = $line.Length - $line.TrimStart().Length
        $spaces = ' ' * $indent
        if ($text -eq '' -or $text -eq '/') {
          # Ligne purement separateur -> supprimer
          continue
        } else {
          $newLines.Add("${spaces}// $text")
        }
      } else {
        $newLines.Add($line)
      }
    }

    $newContent = [string]::Join("`n", $newLines)

    if ($newContent -ne $original) {
      [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.UTF8Encoding]::new($false))
      $totalFixed++
      Write-Host "Corrige: $($file.FullName)"
    }
  }
}

Write-Host "`nTotal fichiers corriges: $totalFixed"
