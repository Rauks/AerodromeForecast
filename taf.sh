tafError(){
  if [[ -n "$1" ]]; then
    echo "Error : $1" >&2 
  else
    echo "Error" >&2 
  fi
}
tafAuthLand(){
  if [[ `expr ':de:fr:it:bl:se:po:as:ch:' : ".*:$1:.*"` -eq 0 ]]; then
    echo 0
  else
    echo 1
  fi
}

#Init
tafInit(){
  rm -r -f ./cache
  rm -r -f ./index.html
  echo "Cache cleared"
}

#Download
tafCache(){
  if [[ -s "./cache/web/$2" ]]; then
    echo "# File already in cache"
  else
    curl -# --create-dirs -o "./cache/web/$2" "$1"
  fi
}
tafDownload(){
  if [[ `tafAuthLand "$1"` -eq 0 ]]; then
    tafError "-d expects parameter 1 to be a land [de fr it bl se po as ch]"
  else
    echo "Downloading TAF datas from web (2 files)"
    tafCache "http://wx.rrwx.com/taf-$1.htm" "$1.html"
    tafCache "http://wx.rrwx.com/taf-$1-txt.htm" "$1.txt"
  fi
}

#Extract
tafExtractReset(){
  rm -r -f ./cache/extracts.taf
}
tafExtract(){
  if [[ -z $2 ]]; then
    tafError "-e expects 2 parameters"
  elif [[ `tafAuthLand "$1"` -eq 0 ]]; then
    tafError "-e expects parameter 1 to be a land [de fr it bl se po as ch]"
  else
    local icao=`sed -n "s:.*>$2</td><td valign=\"top\"><b>\([A-Z]*\)<.*:\1:p" < "./cache/web/$1.html"`
    if [[ -z $icao ]]; then
      tafError "unknow airport"
    else
      mkdir -p "./cache/"
      grep "^$icao " < "./cache/web/$1.txt" >> "./cache/extracts.taf"
      echo "TAF extracted"
    fi
  fi
}

#Analize
tafAnalizeEmited(){
  echo "$1" | sed -n "s:\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)Z:<li><strong>Emited \:</strong> Day \1 @ \2h \3m</li>:p"
}
tafAnalizePeriod(){
  echo "$1" | sed -n "s:\([0-9][0-9]\)\([0-9][0-9]\)/\([0-9][0-9]\)\([0-9][0-9]\):<li><strong>Period \:</strong> Day \1 @ \2h 00m <strong>to</strong> \3 @ \4h 00m</li>:p"
}
tafAnalizeWind(){
  echo "$1" | sed -n "s:\([0-9][0-9][0-9]\)\([0-9][0-9]\).*:<li><strong>Wind \:</strong> \1 deg @ \2 KT</li>:p"
}
tafAnalizeRafaleWind(){
  echo "$1" | sed -n "s:\([0-9][0-9][0-9]\)\([0-9][0-9]\)G\([0-9][0-9]\).*:<li><strong>Wind \:</strong> \1 deg @ \2 KT <strong>Gust</strong> @ \3 KT</li>:p"
}
tafAnalizeVariableWind(){
  echo "$1" | sed -n "s:.*\([0-9][0-9]\).*:<li><strong>Wind \:</strong> Variable @ \2 KT</li>:p"
}
tafAnalizeClouds(){
  local clouds=`echo "$1" | sed -n "s:.*\([A-Z][A-Z][A-Z]\).*:\1:p"`
  local alt=`echo "$1" | sed -n "s:.*\([0-9][0-9][0-9]\).*:\1:p"`
  case $clouds in
    BKN) echo "<li><strong>Clouds :</strong> Broken @ $alt ft</li>";;
    FEW) echo "<li><strong>Clouds :</strong> Few clouds @ $alt ft</li>";;
    SCT) echo "<li><strong>Clouds :</strong> Scattered @ $alt ft</li>";;
    OHD) echo "<li><strong>Clouds :</strong> Overhead @ $alt ft</li>";;
    OVC) echo "<li><strong>Clouds :</strong> Overcast @ $alt ft</li>";;
    TCU) echo "<li><strong>Clouds :</strong> Towering cumulus @ $alt ft</li>";;
  esac
}
tafAnalize(){
  echo "TAF analizing..."
  echo "<!DOCTYPE html><html><head><title>Analized TAF</title></head><body><ul>" > "./index.html"
  while read line; do 
    for word in $line; do 
      case $word in
        LF[A-Z][A-Z]) echo "</ul><h1>Code ICAO : $word</h1><ul>" >> "./index.html";; #Code ICAO
        BECMG) echo "</ul><h2>Becoming</h2><ul>" >> "./index.html";; #Becoming
        TEMPO) echo "</ul><h2>Temporary</h2><ul>" >> "./index.html";; #Temporary
        PROB30) echo "</ul><h2>Probability : 30%</h2><ul>" >> "./index.html";; #Prob. 30%
        PROB40) echo "</ul><h2>Probability : 40%</h2><ul>" >> "./index.html";; #Prob. 40%
        [0-9][0-9][0-9][0-9][0-9][0-9]Z) tafAnalizeEmited $word >> "./index.html";; #Emited date
        [0-9][0-9][0-9][0-9]/[0-9][0-9][0-9][0-9]) tafAnalizePeriod $word >> "./index.html";; #Period date
        VRB[0-9][0-9]KT) tafAnalizeVariableWind $word >> "./index.html";; #Variable wind
        [0-9][0-9][0-9][0-9][0-9]KT) tafAnalizeWind $word >> "./index.html";; #Simple wind
        [0-9][0-9][0-9][0-9][0-9]G[0-9][0-9]KT ) tafAnalizeRafaleWind $word >> "./index.html";; #Rafale wind
        CAVOK) "<li><strong>Clouds : </strong>Ok</li>" >> "./index.html";; #Clouds ok
        NSC) "<li><strong>Clouds : </strong>Not significant</li>" >> "./index.html";; #Clouds ns
        [A-Z][A-Z][A-Z][0-9][0-9][0-9]) tafAnalizeClouds $word >> "./index.html";; #Clouds
      esac
    done 
  done < "./cache/extracts.taf"
  echo "</ul></body></html>" >> "./index.html"
  echo "TAF analized"
}

#Process
tafProcess(){
  tafExtractReset
  if [[ -z $2 ]]; then
    tafError "-p expects 2 parameters"
  elif [[ `tafAuthLand "$1"` -eq 0 ]]; then
    tafError "-p expects parameter 1 to be a land [de fr it bl se po as ch]"
  else
    tafDownload "$1"
    tafExtract "$1" "$2"
    tafAnalize
  fi
}

#Plan
tafPlan(){
  tafExtractReset
  while [[ $# -ge 1 ]]; do
    tafDownload "$1"
    tafExtract "$1" "$2"
    shift 2
  done
  tafAnalize
}

#Main
if [[ $# -lt 1 ]]; then
  tafError "taf expects at least 1 parameter [-i -d -e -a -p -t]"
else
  while [[ $# -ge 1 ]]; do
    case "$1" in
      -i) shift; tafInit;;
      -d) shift; tafDownload "$1"; shift;;
      -e) shift; tafExtract "$1" "$2"; shift 2;;
      -a) shift; tafAnalize;;
      -p) shift; tafProcess "$1" "$2"; shift 2;;
      -t) shift; tafPlan "$@"; shift $#;;
      *) tafError "unknow parameter \"$1\", taf expects parameter [-i -d -e -a -p -t]"; shift;;
    esac
  done
fi