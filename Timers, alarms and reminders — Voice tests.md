# Timers, alarms and reminders — voice tests

Say these to the satellite; tick them off. "→" is what should happen. Items without a room ring
everywhere (currently: the living-room Sonos).

## Timers

- [ ] "Timer auf 5 Minuten" → *5 Minuten Timer – ab jetzt.*
- [ ] "Stelle einen Timer auf eine Minute und dreißig Sekunden" → 1:30, not 30 s
- [ ] "Timer auf 1 Stunde und 15 Minuten"
- [ ] "Timer auf eine halbe Stunde" / "eine Viertelstunde" / "anderthalb Stunden"
- [ ] "Stelle einen Nudel Timer auf 8 Minuten" → *Nudel-Timer auf 8 Minuten – ab jetzt.*
- [ ] "15 Minuten ab jetzt"
- [ ] "Wie lange noch" → all timers with their remaining time
- [ ] "Wie lange läuft der Nudel Timer noch"
- [ ] "Verlängere den Timer um 2 Minuten" (with two timers running → *Welchen meinst du? …*)
- [ ] "Füge dem 5 Minuten Timer eine Minute hinzu"
- [ ] "Ziehe 30 Sekunden ab"
- [ ] "Pausiere den Timer" → "Setze den Timer fort"
- [ ] "Lösche den Nudel Timer"
- [ ] "Alle Timer abbrechen"

## When something rings

- [ ] "Stopp" while a timer rings → quiet, no reply
- [ ] "Stopp" with music playing and nothing ringing → speakers go quiet
- [ ] "Noch mal" after a timer rang → *Okay, in 10 Minuten noch mal.*
- [ ] "In 2 Minuten noch mal" while it rings
- [ ] Timer/reminder while quiet music plays → chime and text clearly audible (fixed 30 %), music ducks

## Reminders

- [ ] "Erinnere mich in 2 Minuten an den Tee" → rings twice: chime, text, ~5 s, chime, text
- [ ] Same, but "Stopp" after the first text → no second pass
- [ ] "Erinnere mich um 13:30 Uhr an den Zahnarzt" → 13:30, not 10 Uhr
- [ ] "Erinnere mich morgen um 7 Uhr 15 an die Tabletten" → 7:15, not 7:00
- [ ] "Erinnere mich morgen früh an den Müll" → tomorrow 8:00
- [ ] "Erinnere mich heute um 9 Uhr an X" (after 9) → *Dieser Zeitpunkt ist schon vorbei.*
- [ ] "Erinnere mich am Samstag an die Blumen" → Saturday 9:00
- [ ] "Was steht heute an" / "Was steht morgen an"
- [ ] "Welche Erinnerungen habe ich am Freitag"
- [ ] "Lösche die Erinnerung an den Tee"
- [ ] Check the new entry in Thunderbird: category `HomeAssistant Reminder` plus `Wohnzimmer`

## Alarms

- [ ] "Stelle einen Wecker für 7 Uhr" → rings at one volume
- [ ] "Weck mich morgen um 6:30" → gets louder every round ("Sanft")
- [ ] "Weck mich um 7 Uhr mit Musik" → default playlist, quietly getting louder
- [ ] "Weck mich morgen um 7 mit der Playlist <name>"
- [ ] "Stelle einen Wecker werktags um 7 Uhr mit Musik" → repeating, music (new)
- [ ] "Stelle einen Wecker für 7 Uhr mit der Playlist <name>" (new)
- [ ] "Wecker werktags um 6:45" / "Weck mich jeden Tag um 7 Uhr"
- [ ] "Wann klingelt der Wecker" → the next alarm, never a reminder
- [ ] "Kein Wecker morgen" / "Weck mich am Samstag nicht"
- [ ] "Deaktiviere den Wecker um 7 Uhr" → "Aktiviere den Wecker um 7 Uhr"
- [ ] "Lösche den Wecker um 7 Uhr"
- [ ] While a music alarm plays: "Stopp" → music keeps playing, ducked *Wecker beendet.*
- [ ] While a music alarm plays: "Noch mal" → music pauses, starts again quietly later

## From the calendar (Thunderbird)

- [ ] Entry with categories `HomeAssistant Reminder` + `Küche`, `Wohnzimmer` → rings on both rooms' speakers
- [ ] Entry with no room category → rings everywhere
- [ ] Entry with a Location → *… Ort: <location>.* in the text
- [ ] Reminders at 15 and 0 minutes before → *… in 15 Minuten. Ich erinnere dich zum Beginn noch mal.*
- [ ] Alarm entry with Status *Cancelled* → doesn't ring
- [ ] Alarm with description `Sanft` / `Musik: <playlist>`
- [ ] Entry length in HA's calendar view matches Thunderbird

## Known gaps (shouldn't work yet)

- "halb sieben", "Viertel nach sieben"
- Dates ("am 3. November")
- Short-form names ("Nudel Timer auf 8 Minuten" names nothing; use "Stelle einen Nudel Timer …")
