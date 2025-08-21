{ config, pkgs, ... }:
pkgs.writers.writePython3Bin "waybar-calendar" { libraries = [ pkgs.python313Packages.caldav ]; } # python
  ''
    from caldav import DAVClient
    from datetime import datetime, timedelta, timezone

    CALDAV_ACCOUNTS = [
        "${config.age.secrets.waybar-calendar-personal.path}",
    ]


    def parse_secret_file(path):
        with open(path) as f:
            lines = [line.strip().replace('"', "") for line in f if "=" in line]
            return dict(line.split("=", 1) for line in lines)


    now = datetime.now(timezone.utc)
    soon = now + timedelta(hours=2)

    closest_event = None
    closest_start = None

    for path in CALDAV_ACCOUNTS:
        try:
            account = parse_secret_file(path)
            client = DAVClient(
                url=account["url"],
                username=account["username"],
                password=account["password"],
            )
            principal = client.principal()
            calendars = principal.calendars()

            for calendar in calendars:
                events = calendar.date_search(
                    start=now - timedelta(hours=2),
                    end=soon
                )
                for event in events:
                    try:
                        vevent = event.vobject_instance.vevent
                        start = vevent.dtstart.value
                        end = (
                            vevent.dtend.value
                            if hasattr(vevent, "dtend")
                            else start
                        )

                        if isinstance(start, datetime) and not start.tzinfo:
                            start = start.replace(tzinfo=timezone.utc)
                        if isinstance(end, datetime) and not end.tzinfo:
                            end = end.replace(tzinfo=timezone.utc)

                        if (start <= now < end) or (now <= start <= soon):
                            if closest_start is None or start < closest_start:
                                closest_event = vevent
                                closest_start = start
                    except Exception:
                        continue
        except Exception:
            continue

    if closest_event:
        summary = str(closest_event.summary.value)
        time_str = closest_start.astimezone().strftime("%H:%M")
        print(f"󰃰  {time_str} {summary}")
    else:
        print("")
  ''
