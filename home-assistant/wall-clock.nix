{ ... }:
let
  # Remembrance's timers, alarms and reminders, mirrored onto the Echo Wall
  # Clock's LED ring. Neither integration knows the other: this compares what
  # remembrance has with what the clock shows and sets or cancels the
  # difference. The clock integration keeps its alerts across reconnects and
  # restarts by itself, so only remembrance's changes (and startup) matter.
  #
  # Only alerts with the `r-` prefix are touched: anything else on the clock
  # (automations of their own) is left alone.
  prefix = "r-";

  # What should be on the clock, keyed by alert id:
  # - running timers, until their end;
  # - scheduled alarms and reminders, at their next ring (reminders ring
  #   before the start, at their VALARM);
  # - ringing items stay as they are until remembrance dismisses them (or its
  #   ring limit runs out); then they're gone and cancelled, which also stops
  #   the clock;
  # - paused timers aren't (the clock can't pause); resuming sets them again;
  # - only items for the clock's room: its device's area in HA, or none (an
  #   item without areas rings everywhere). A clock without an area shows all.
  wanted = ''
    {%- set room = integration_entities('echo_wall_clock') | map('area_id')
                   | select | first | default(none) -%}
    {%- set ns = namespace(out={}) -%}
    {%- for i in wanted.get('items', [])
          if room is none or not i.areas or room in i.areas -%}
      {%- set at = i.ends_at if i.kind == 'timer' else i.next_ring -%}
      {%- set live = i.state == ('running' if i.kind == 'timer' else 'scheduled') -%}
      {%- if i.state == 'ringing' -%}
        {%- set ns.out = dict(ns.out, **{'${prefix}' ~ i.id: {'keep': true}}) -%}
      {%- elif live and at and as_datetime(at) > now() + timedelta(seconds=2) -%}
        {%- set ns.out = dict(ns.out, **{'${prefix}' ~ i.id: {
          'kind': i.kind, 'at': at, 'label': i.label or ""}}) -%}
      {%- endif -%}
    {%- endfor -%}
    {{ ns.out }}'';

  # Set, or moved by more than 2 s (timers are set by duration, so a few
  # milliseconds off).
  toSet = ''
    {%- set shown_at = dict(zip(shown.alerts | map(attribute='alert_id'),
                                shown.alerts | map(attribute='at'))) -%}
    {%- set ns = namespace(out=[]) -%}
    {%- for id, w in want.items() if not w.get('keep') -%}
      {%- set cur = shown_at.get(id) -%}
      {%- if cur is none
            or ((as_datetime(cur) - as_datetime(w.at)).total_seconds() | abs) > 2 -%}
        {%- set ns.out = ns.out + [dict(w, id=id,
              seconds=((as_datetime(w.at) - now()).total_seconds() | round(0, 'ceil') | int))] -%}
      {%- endif -%}
    {%- endfor -%}
    {{ ns.out }}'';

  toCancel = ''
    {{ shown.alerts | map(attribute='alert_id')
       | select('match', '${prefix}') | reject('in', want.keys() | list) | list }}'';

  setAlert = kind: data: {
    conditions = "{{ repeat.item.kind == '${kind}' }}";
    sequence = [
      {
        action = "echo_wall_clock.set_${kind}";
        data = {
          alert_id = "{{ repeat.item.id }}";
          label = "{{ repeat.item.label }}";
        }
        // data;
        continue_on_error = true;
      }
    ];
  };
in
{
  hass.scripts.wall_clock_mirror = {
    alias = "Wanduhr: Remembrance spiegeln";
    description = "Bringt die Wanduhr auf den Stand von Remembrance (Timer, Wecker, Erinnerungen).";
    icon = "mdi:clock-time-four-outline";
    mode = "queued";
    sequence = [
      # No clock set up (yet): nothing to do.
      {
        condition = "template";
        value_template = "{{ integration_entities('echo_wall_clock') | count > 0 }}";
      }
      {
        action = "remembrance.query";
        response_variable = "wanted";
      }
      {
        action = "echo_wall_clock.list_alerts";
        response_variable = "shown";
      }
      { variables.want = wanted; }
      {
        variables = {
          to_set = toSet;
          to_cancel = toCancel;
        };
      }
      {
        repeat = {
          for_each = "{{ to_cancel }}";
          sequence = [
            {
              action = "echo_wall_clock.cancel_alert";
              data.alert_id = "{{ repeat.item }}";
              continue_on_error = true;
            }
          ];
        };
      }
      {
        repeat = {
          for_each = "{{ to_set }}";
          sequence = [
            {
              choose = [
                (setAlert "timer" { duration = "{{ repeat.item.seconds }}"; })
                (setAlert "alarm" { at = "{{ repeat.item.at }}"; })
                (setAlert "reminder" { at = "{{ repeat.item.at }}"; })
              ];
            }
          ];
        };
      }
    ];
  };

  hass.automations.wall_clock_mirror = {
    alias = "Wanduhr: Remembrance spiegeln";
    mode = "queued";
    trigger = [
      {
        trigger = "event";
        event_type = "remembrance_changed";
      }
      {
        trigger = "event";
        event_type = "remembrance_dismissed";
      }
      {
        trigger = "event";
        event_type = "remembrance_snoozed";
      }
      {
        trigger = "homeassistant";
        event = "start";
      }
    ];
    action = [ { action = "script.wall_clock_mirror"; } ];
  };
}
