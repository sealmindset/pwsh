$CVEsWanted = @(
    "CVE-2022-24526" 
)

#Location of output HTML Report
$HTML_Report = "CVE.html"

$Month = "2022-Sep"

$CVRFDoc = Get-MsrcCvrfDocument -ID $Month -Verbose
$CVRFHtmlProperties = @{
    Vulnerability = $CVRFDoc.Vulnerability | Where-Object { $_.CVE -in $CVEsWanted }
    ProductTree   = $CVRFDoc.ProductTree
}
#Generate the HTML Report
Get-MsrcVulnerabilityReportHtml @CVRFHtmlProperties -Verbose | Out-File $HTML_Report
#Open the HTML Report with Broswer
Invoke-Item $HTML_Report
