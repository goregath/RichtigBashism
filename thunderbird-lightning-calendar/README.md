# Read calender Thunderbird (Lightning)

```plain
thunderbird_calendar.sh [-b DIR] [-d [DATE][OFFSET]:LENGTH] [-f FMT] [-h]
  -b, --database-root   Directory of calendar data.
                        Defaults to $HOME/.thunderbird/*/calendar-data
  -d, --date            Query calendar around this date. 
                        Defaults to today
  -f, --format          Chose output format
  -h, --help            Display this message and exit

  DATE    First form:  YYYY.MM.DD
          Second form: fo(w|m|y)
          ┌──────────┬───────┬───────┬───────┐
          │          │ Week  │ Month │ Year  │
          ├──────────┼───────┼───────┼───────┤
          │ First of │ fow   │ fom   │ foy   │
          └──────────┴───────┴───────┴───────┘
          Note: First of week is defined as monday.

  OFFSET  (-|+)NUM[UNIT]
  LENGTH  [-|+]NUM[UNIT]
  NUM     A signed integer
  UNIT    y: Year, m: Month, w: Week, d: Day (default)

FORMAT:
  Supported formats are yad and raw (dash separated values).

OUTPUT:
  Each line on stdout contains a day with one or more events.
  Events start with one of the following marker:

    [HH:MM] Local time
    [~]     Continuous event (multiple days)
    [=]     Whole day

EXAMPLES:
  Query events starting one month before and after a date
  $ thunderbird_calendar.sh -d 2020.01.01-1m:2m

  Query events for one weak starting at a date
  $ thunderbird_calendar.sh -d 2019.03.01:1w

  Query events for current month
  $ thunderbird_calendar.sh -d fom:1m
```

```bash
BASH_INCLUDES=.. ./thunderbird_calendar.sh -d 2019.04.01-1m:2m
[INFO] [SRC] included ../include/logger.sh
[INFO] [SRC] included ../include/execution.sh
[INFO] BEGIN: Fri Mar  1 00:00:00 CET 2019
[INFO] END:   Tue Apr 30 23:59:59 CEST 2019
01.03.2019 [18:00] Poker bei Maik [22:00] Naddel
08.03.2019 [16:00] Ölwechsel [=] Frauentag (§)
17.03.2019 [18:00] Filmabend
22.03.2019 [~] Camping
23.03.2019 [~] Camping
24.03.2019 [~] Camping
25.03.2019 [17:00] Bierchen mit Thomas
18.04.2019 [08:00] Naddel [=] Gründonnerstag
19.04.2019 [10:00] Quad-Tour [=] Karfreitag (§)
22.04.2019 [=] Ostermontag (§)
23.04.2019 [~] Lisa Waldhaus
26.04.2019 [18:15] Geburtstag Maik [18:30] Globetrotter
27.04.2019 [~] Campen [~] Fontane Rallye
28.04.2019 [~] Campen
[WARN] missing execution::teardown()
```