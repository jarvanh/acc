batt_info() {

  local info="" voltNow="" currNow="" powerNow="" factor=""
  set +euo pipefail 2>/dev/null || :


  # calculator
  calc() { awk "BEGIN { print $* }"; }


  # (determine conversion factor)
  dtr_conv_factor() {
    factor=0
    [ $1 -lt 10000 -a $1 -ne 0 ] && factor=1000 || factor=1000000
  }


  # raw battery info from $batt/uevent
  info="$(
    sed -e 's/^POWER_SUPPLY_//' -e 's/^BATT_VOL=/VOLTAGE_NOW=/' -e 's/^BATT_TEMP=/TEMP=/' \
      -e "/^CAPACITY=/s/=.*/=$(( $(cat $batt/capacity) ${capacity[4]} ))/" $batt/uevent

    [ ! -f bms/uevent ] || {
      grep -q '^P.*_PPLY_TEMP=' $batt/uevent \
        || sed -n '/^P.*_PPLY_TEMP=/s/.*Y_T/T/p' bms/uevent || :
      grep -q '^P.*_PPLY_VOLTAGE_NOW=' $batt/uevent \
        || sed -n '/^P.*_PPLY_VOLTAGE_NOW=/s/.*Y_V/V/p' bms/uevent || :
    }
  )"


  # because MediaTek is weird
  [ ! -d /proc/mtk_battery_cmd ] || {
    echo "$info" | grep '^CURRENT_NOW=' > /dev/null \
      || info="${info/BATTERYAVERAGECURRENT=/CURRENT_NOW=}"
  }


  # parse CURRENT_NOW & convert to Amps
  currNow=$(echo "$info" | sed -n "s/^CURRENT_NOW=//p")
  dtr_conv_factor ${currNow#-}
  currNow=$(calc ${currNow:-0} / $factor)


  # parse VOLTAGE_NOW & convert to Volts
  voltNow=$(echo "$info" | sed -n "s/^VOLTAGE_NOW=//p")
  dtr_conv_factor $voltNow
  voltNow=$(calc ${voltNow:-0} / $factor)


  # calculate POWER_NOW (Watts)
  powerNow=$(calc $currNow \* $voltNow)


  {
    # print raw battery info
    ${verbose-false} \
      && echo "$info" \
      || echo "$info" | grep -Ev '^(CURRENT|VOLTAGE)_NOW='

    # print CURRENT_NOW, VOLTAGE_NOW and POWER_NOW
    echo "
CURRENT_NOW=$currNow$(print_A 2>/dev/null || :)
VOLTAGE_NOW=$voltNow$(print_V 2>/dev/null || :)
POWER_NOW=$powerNow$(print_W 2>/dev/null || :)"
  } | grep -Ei "${1:-.*}"
}
