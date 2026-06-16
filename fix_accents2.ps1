
$pairs = @(
  # à
  @('mis é jour','mis à jour'), @('mise é jour','mise à jour'), @('mises é jour','mises à jour'),
  @('déjé','déjà'), @('Déjé','Déjà'),
  @('voilé','voilà'), @('Voilé','Voilà'),
  @(' é chaque',' à chaque'), @(' é partir',' à partir'),
  @(" é l'"," à l'"), @(' é la ',' à la '),
  @(' é votre',' à votre'), @(' é vous',' à vous'), @(' é nous',' à nous'),
  @(' é travers',' à travers'), @(' é tout',' à tout'), @(' é distance',' à distance'),
  @(' é jour',' à jour'),
  # ç
  @('Aperéu','Aperçu'), @('aperéu','aperçu'),
  @('Faéon','Façon'), @('faéon','façon'),
  @('Garéon','Garçon'), @('garéon','garçon'),
  @('reéus','reçus'), @('reéu ','reçu '),
  # ê
  @('arréter','arrêter'), @('arrétez','arrêtez'), @('arréte','arrête'), @('Arréte','Arrête'),
  @('fenétre','fenêtre'), @('conquéte','conquête'),
  @('méme','même'), @('Méme','Même'),
  @('Préts','Prêts'), @('préts','prêts'),
  @('Préte','Prête'), @('préte','prête'),
  @('Prét ','Prêt '), @('prét ','prêt '),
  @('Téte','Tête'), @('téte','tête'),
  @('Féte','Fête'), @('féte','fête'),
  # è — -ès
  @('SUCCÉS','SUCCÈS'), @('Succés','Succès'), @('succés','succès'),
  @('Aprés','Après'), @('aprés','après'),
  @('Trés','Très'), @('trés','très'),
  @('Auprés','Auprès'), @('auprés','auprès'),
  @('ACCÉS','ACCÈS'), @('Accés','Accès'), @('accés','accès'),
  # è — -ème
  @('Probléme','Problème'), @('probléme','problème'),
  @('SYSTÉME','SYSTÈME'), @('Systéme','Système'), @('systéme','système'),
  @('Théme','Thème'), @('théme','thème'),
  # è — -ète
  @('Compléte','Complète'), @('compléte','complète'),
  @('Complétement','Complètement'), @('complétement','complètement'),
  @('Incompléte','Incomplète'), @('incompléte','incomplète'),
  # è — -ère
  @('Derniéres','Dernières'), @('derniéres','dernières'),
  @('Derniére','Dernière'), @('derniére','dernière'),
  @('Premiéres','Premières'), @('premiéres','premières'),
  @('Premiére','Première'), @('premiére','première'),
  @('arriére','arrière'),
  @('BANNIÉRE','BANNIÈRE'), @('Banniére','Bannière'), @('banniére','bannière'),
  @('Financiéres','Financières'), @('financiéres','financières'),
  @('Financiére','Financière'), @('financiére','financière'),
  @('Lumiére','Lumière'), @('lumiére','lumière'),
  @('Maniéres','Manières'), @('maniéres','manières'),
  @('Maniére','Manière'), @('maniére','manière'),
  @('matiéres','matières'), @('matiére','matière'),
  @('Carriére','Carrière'), @('carriére','carrière'),
  # è — autres
  @('Aréne','Arène'), @('aréne','arène'),
  @('Modéle','Modèle'), @('modéle','modèle'),
  @('Réglements','Règlements'), @('réglements','règlements'),
  @('Réglement','Règlement'), @('réglement','règlement'),
  @('Régles','Règles'), @('régles','règles'),
  @('Régle','Règle'), @('régle','règle'),
  @('PARAMÉTRE','PARAMÈTRE'), @('PARAMÉTRES','PARAMÈTRES'),
  @('Paramétres','Paramètres'), @('paramétres','paramètres'),
  @('Paramétre','Paramètre'), @('paramétre','paramètre'),
  @('Enléve','Enlève'), @('enléve','enlève'),
  @('Génére','Génère'), @('génére','génère'),
  @('1ére','1ère'),
  # ô
  @('biéntot','bientôt'),
  @('Clotures','Clôtures'), @('clotures','clôtures'),
  @('Cloture','Clôture'), @('cloture','clôture'),
  # â
  @('Gateau','Gâteau'), @('gateau','gâteau'),
  # û
  @('Aout','Août'), @('aout','août'),
  # î
  @('Fraiche','Fraîche'), @('fraiche','fraîche'),
  @('apparaitront','apparaîtront'), @('apparaitre','apparaître'),
  @('paraitre','paraître'), @('connaitre','connaître')
)

$projects = @('c:\flutter_application_2','c:\allofoods_admin','c:\allofoods_merchant','c:\allofoods_driver')
$fixed = 0
foreach ($proj in $projects) {
  $lib = Join-Path $proj 'lib'
  if (-not (Test-Path $lib)) { continue }
  Get-ChildItem $lib -Filter '*.dart' -Recurse | ForEach-Object {
    $path = $_.FullName
    $c = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
    $orig = $c
    foreach ($p in $pairs) { $c = $c.Replace($p[0], $p[1]) }
    if ($c -ne $orig) {
      [System.IO.File]::WriteAllText($path, $c, [System.Text.UTF8Encoding]::new($false))
      $fixed++
    }
  }
}
Write-Host "Fichiers corrigés: $fixed"
