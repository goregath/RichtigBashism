# Read calender Thunderbird (Lightning)

```plain
thunderbird_calendar.sh [-d [DATE][OFFSET]:LENGTH] [-h]
  -d, --date    Query calendar around this date. 
                Defaults to today
  -h, --help    Display this message and exit

  DATE    First form:  YYYY.MM.DD
          Second form: (f|l)o(d|w|m|y)
          ┌──────────┬───────┬───────┬───────┬───────┐
          │          │ Day   │ Week  │ Month │ Year  │
          ├──────────┼───────┼───────┼───────┼───────┤
          │ First of │ fod   │ fow   │ fom   │ foy   │
          │ Last of  │ lod   │ low   │ lom   │ loy   │
          └──────────┴───────┴───────┴───────┴───────┘
  OFFSET  (-|+)NUM[UNIT]
  LENGTH  [-|+]NUM[UNIT]
  NUM     A signed integer
  UNIT    y: Year, m: Month, w: Week, d: Day (default)

EXAMPLES:
  Query events starting one month before and after a date
  $ thunderbird_calendar.sh -d 2020.01.01-1m:2m

  Query events for one weak starting at a date
  $ thunderbird_calendar.sh -d 2019.03.01:1w
```

```bash
$ ./thunderbird_calendar.sh -d 2019.04.01-1m:2m
[INFO] BEGIN: Fri Mar  1 00:00:00 CET 2019
[INFO] END:   Tue Apr 30 23:59:59 CEST 2019
01.03.2019 [18:00] Poker [22:00] Naddel
08.03.2019 [16:00] Ölwechsel [=] Frauentag (§)
17.03.2019 [18:00] Filmabend
22.03.2019 [~] Camping
23.03.2019 [~] Camping
24.03.2019 [~] Camping
25.03.2019 [17:00] Bierchen mit Thomas
18.04.2019 [=] Gründonnerstag
19.04.2019 [10:00] Quad-Tour [=] Karfreitag (§)
22.04.2019 [=] Ostermontag (§)
27.04.2019 [~] Campen [~] Fontane Rallye
28.04.2019 [~] Campen
```

