function Get-iTunesItem {
    param(
        [Parameter(Mandatory=$true,ParameterSetName="byId")][string]$id,
        [Parameter(Mandatory=$true,ParameterSetName="byBundleId")][string]$bundleId
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
    if ($id -ne "") {
        $storeUrl = "https://itunes.apple.com/lookup?id=$id"
    } elseif ($bundleId -ne "") {
        $storeUrl = "https://itunes.apple.com/lookup?bundleId=$bundleId"
    }
    $storeResponse = Invoke-WebRequest -method GET -Uri $storeUrl
    $storeItem = ($storeResponse | ConvertFrom-JSON).results
    return $storeItem
}
Export-ModuleMember -Function Get-itunesItem

function Get-depUrls {
    param(
        [Parameter(Mandatory=$true)][string]$depUrl
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
    $discoveryResponse = Invoke-WebRequest -Uri $depUrl
    $discoveryJSON = ($discoveryResponse.content | ConvertFrom-JSON)
    $enrollmentUri = [System.Uri]$discoveryJSON.dep_enrollment_url
    $anchorUrl = $discoveryJSON.dep_anchor_certs_url
    $testUrl = $enrollmentUri.scheme + '://' + $enrollmentUri.host
    $enrollResponse = Invoke-WebRequest -Uri $testUrl # -MaximumRedirection 0 -ErrorAction SilentlyContinue
    $servicePoint = [System.Net.ServicePointManager]::FindServicePoint($testUrl)
    $cert = $servicePoint.Certificate
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    $chain.Build($cert) | Out-null
    $root1 = ($chain.ChainElements | Select-Object -Last 1).Certificate
    $thumb1 = $root1.thumbprint
    $anchorResponse = Invoke-WebRequest -Uri $anchorUrl
    $base64 = $anchorResponse.content | ConvertFrom-JSON
    $root2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($base64))
    $thumb2 = $root2.thumbprint
    $depUrls = New-Object PSObject
    $depUrls | add-member -NotePropertyName depEnrollmentUrl -NotePropertyValue $enrollmentUri.originalString
    $depUrls | add-member -NotePropertyName depAnchorCertUrl -NotePropertyValue $anchorUrl
    $depUrls | add-member -NotePropertyName isProxied -NotePropertyValue ($thumb1 -ne $thumb2)
    $depUrls | add-member -NotePropertyName depAnchorCert -NotePropertyValue $root2
    return $depUrls
}
Export-ModuleMember -Function Get-depUrls

function Get-vppInfo {
    param(
        [Parameter(Mandatory=$true)][string]$tokenfile
    )
    $vppToken = Get-Content -Path $tokenfile
    $vppBody = '{"includeLicenseCounts":"true","sToken":"' + $vppToken + '"}' 
    $vppUrl = "https://vpp.itunes.apple.com/mdm/getVPPAssetsSrv"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
    $vppResponse = Invoke-WebRequest -method POST -Uri $vppUrl -Body $vppBody
    $vppTokenInfo = $vppResponse | ConvertFrom-JSON
    return $vppTokenInfo
}
Export-ModuleMember -Function Get-vppInfo

function Get-vppAssets {
    param(
        [Parameter(Mandatory=$true)][string]$tokenfile
    )
    $vppToken = Get-Content -Path $tokenfile
    $vppBody = '{"includeLicenseCounts":"true","sToken":"' + $vppToken + '"}' 
    $vppUrl = "https://vpp.itunes.apple.com/mdm/getVPPAssetsSrv"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12
    $vppResponse = Invoke-WebRequest -method POST -Uri $vppUrl -Body $vppBody
    $vppTokenInfo = $vppResponse | ConvertFrom-JSON
    foreach ($asset in $vppTokenInfo.assets) {
        $storeUrl = "https://itunes.apple.com/lookup?id=$($asset.adamIdStr)"
        $storeResponse = Invoke-WebRequest -method GET -Uri $storeUrl
        $storeJSON = $storeResponse | ConvertFrom-JSON
        $asset | add-member -NotePropertyName assetName -NotePropertyValue $storeJSON.results.trackname
    }
    return $vppTokenInfo.assets
}
Export-ModuleMember -Function Get-vppAssets