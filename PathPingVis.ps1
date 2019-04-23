$ErrorActionPreference = "stop"

function get-randomString() {
    -join ((65..90) + (97..122) | Get-Random -Count 12 | foreach-object { [char]$_ })
}

function printTree($tree) {
    $nodeLabel = '"' + $tree.ip + '\n' + $tree.hostname + '"'
    foreach ($child in $tree.children) {
        $childLabel = '"' + $child.ip + '\n' + $child.hostname + '"'
        Write-Output ($nodeLabel + "->" + $childLabel).replace(" ", "\n")
        printTree $child
    }
}

function isChild($ip, $children) {
    foreach ($child in $children) {
        if ($ip -eq $child.ip -and $ip -ne '0.0.0.0') {
            $script:foundChild = $child
            return $true;
        }
    }
    return $false
}

function makeNode($ip, $domain) {
    if ($ip -ne "0.0.0.0" ) {
        $nodeHostName = (Resolve-DnsName $ip -ErrorAction silentlycontinue -QuickTimeout ).NameHost
    }
    else {
        $nodeHostName = "unknown_host " + (get-randomString)
    }
    New-Object -TypeName psobject -Property @{hostname = $nodeHostName; ip = $ip; children = @() }
}
function createTree(){
    $domains = Get-Content .\top_domains.txt
    $global:rootNode = New-Object -TypeName psobject -Property @{hostname = "root node"; ip = "N/A"; children = @() }

    foreach ($domain in $domains) {
        $currentNodeTree = $global:rootNode 
        $previousNodeTree = $global:rootNode
        Write-Host "Getting route for domain: $domain"
        $result = Test-NetConnection $domain -TraceRoute
        $route = $result.TraceRoute
        foreach ($ip in $route) {
            if (isChild $ip $previousNodeTree.children) {
                $currentNodeTree = $script:foundChild 
            }
            else {
                $currentNode = makeNode $ip $domain
                $currentNodeTree.children += $currentNode
                $currentNodeTree = $currentNode
            }
            write-host ("`t" + $currentNodeTree.ip + ' ' + $currentNodeTree.hostname)
            $previousNodeTree = $currentNodeTree
        }
        $leaf = New-Object -TypeName psobject -Property @{hostname = $domain; ip = "N/A"; children = @() }
        $currentNodeTree.children += $leaf 
    }
}

function main(){
    createTree
    "digraph G {" | out-file -encoding ASCII .\graph.dot
    printTree $rootNode | out-file -encoding ASCII -Append .\graph.dot
    "}" | out-file -encoding ASCII -Append .\graph.dot
    & "C:\Program Files (x86)\Graphviz2.38\bin\dot.exe" -Tsvg -o graph.svg .\graph.dot 
}