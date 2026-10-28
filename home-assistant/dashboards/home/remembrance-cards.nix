{ lib }:
# Cards for remembrance's timers, reminders and alarms, shared by the views.
let
  ha = lib.ha;

  # The banner's look (mkActiveBanner) without its conditional wrapper, so
  # auto-entities sets the entity on the button itself. Tap cancels.
  timerBanner = ha.mkActionCard {
    entity = "this.entity_id";
    cardBg = "var(--yellow)";
    iconColor = "var(--black)";
    nameColor = "var(--black)";
    labelColor = "var(--black)";
    zIndex = 1;
    extraCardProps."margin-top" = "24px";
    name = "[[[ return entity.attributes.label ? 'Timer ' + entity.attributes.label : 'Timer'; ]]]";
    icon = "[[[ return entity.attributes.state === 'paused' ? 'mdi:timer-pause' : 'mdi:timer-sand'; ]]]";
    label = "[[[ const a = entity.attributes; if (a.state === 'ringing') return 'Abgelaufen'; if (a.state === 'paused') { const r = Math.round(a.remaining); return 'Pausiert, noch ' + Math.floor(r / 60) + ':' + String(r % 60).padStart(2, '0'); } return 'Endet um ' + new Date(a.ends_at).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }); ]]]";
    service = "remembrance.timer_cancel";
    serviceData.entity_id = "this.entity_id";
    confirmation = "Timer wirklich abbrechen?";
  };

  timerButton =
    name: icon: service: data:
    ha.mkServiceButton {
      inherit name icon service;
      serviceData = {
        entity_id = "this.entity_id";
      }
      // data;
      height = 56;
      haptic = "medium";
    };

  # One card per timer sensor; they come and go, so auto-entities builds
  # them. `options` is the card per timer, `this.entity_id` its sensor.
  perTimer = options: {
    type = "custom:auto-entities";
    show_empty = false;
    card.type = "vertical-stack";
    card_param = "cards";
    sort = {
      method = "attribute";
      attribute = "ends_at";
    };
    filter.include = [
      {
        domain = "sensor";
        integration = "remembrance";
        attributes.kind = "timer";
        inherit options;
      }
    ];
  };
in
{
  # The home view's status banners: one per timer.
  timerBanners = perTimer timerBanner;

  # The banner plus +1 minute, pause and resume.
  timerControls = perTimer (
    ha.mkVStack [
      timerBanner
      (ha.mkHStack [
        (timerButton "+1 min" "mdi:plus" "remembrance.timer_adjust" { delta = 60; })
        (timerButton "Pause" "mdi:pause" "remembrance.timer_pause" { })
        (timerButton "Weiter" "mdi:play" "remembrance.timer_resume" { })
      ])
    ]
  );

  # Quick start, in the room the dashboard doesn't know: rings where the
  # remembrance default (or the ring script's fallback) says.
  timerQuickStart = map (minutes:
    ha.mkButtonBlue {
      name = "${toString minutes} min";
      icon = "mdi:timer-plus-outline";
      service = "remembrance.timer_start";
      serviceData.duration = minutes * 60;
    }
  ) [ 5 10 15 30 ];

  # Repeating alarms, each a switch (enabled or not).
  alarmSwitches = {
    type = "custom:auto-entities";
    show_empty = false;
    card = {
      type = "entities";
      title = "Wecker";
    };
    filter.include = [
      {
        domain = "switch";
        integration = "remembrance";
      }
    ];
  };

  # Upcoming tagged reminders and alarms from the calendar.
  upcoming = {
    type = "calendar";
    entities = [ "calendar.remembrance" ];
    initial_view = "listWeek";
  };
}
