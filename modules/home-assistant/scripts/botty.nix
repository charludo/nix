{ lib, config, ... }:
let
  e = config.hass.entities;
in
{
  hass.scripts = {
    botty_reinigung = {
      alias = "Botty Reinigung";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          "if" = [
            {
              condition = "and";
              conditions = [
                {
                  condition = "state";
                  entity_id = e.input_boolean.botty_wohnzimmer_reinigen;
                  state = "off";
                }
                {
                  condition = "state";
                  entity_id = e.input_boolean.botty_kueche_reinigen;
                  state = "off";
                }
                {
                  condition = "state";
                  entity_id = e.input_boolean.botty_buro_reinigen;
                  state = "off";
                }
                {
                  condition = "state";
                  entity_id = e.input_boolean.botty_sofa_reinigen;
                  state = "off";
                }
              ];
            }
          ];
          "then" = [
            {
              action = "vacuum.send_command";
              data = {
                command = "app_segment_clean";
                params = [
                  {
                    segments = [
                      16
                      17
                    ];
                  }
                ];
              };
              target.entity_id = e.vacuum.botty;
            }
          ];
          "else" = [
            {
              action = "vacuum.send_command";
              data = {
                command = "app_zoned_clean";
                params = ''
                  [{%if states.input_boolean.botty_sofa_reinigen.state=='on'%}
                    [26000,25975,29550,{{states.input_number.botty_wiederholungen.state|int}}],
                  {%endif%} {%if states.input_boolean.botty_kueche_reinigen.state=='on'%}
                    [22400,23700,24125,27825,{{states.input_number.botty_wiederholungen.state|int}}],
                  {%endif%} {%if states.input_boolean.botty_wohnzimmer_reinigen.state=='on'%}
                    [22075,29800,29675,23475,{{states.input_number.botty_wiederholungen.state|int}}],
                  {%endif%} {%if states.input_boolean.botty_buro_reinigen.state=='on'%}
                    [25800,33825,29450,29800,{{states.input_number.botty_wiederholungen.state|int}}],
                  {%endif%}]'';
              };
              target.entity_id = e.vacuum.botty;
            }
          ];
        }
        {
          action = "input_boolean.turn_off";
          data = { };
          target.entity_id = [
            e.input_boolean.botty_wohnzimmer_reinigen
            e.input_boolean.botty_buro_reinigen
            e.input_boolean.botty_kueche_reinigen
            e.input_boolean.botty_sofa_reinigen
          ];
        }
        {
          action = "input_number.set_value";
          data.value = 1;
          target.entity_id = e.input_number.botty_wiederholungen;
        }
      ];
    };

    botty_wiederholungen = {
      alias = "Botty Wiederholungen";
      icon = "mdi:repeat";
      sequence = [
        {
          "if" = [
            {
              condition = "numeric_state";
              entity_id = e.input_number.botty_wiederholungen;
              below = 3;
            }
          ];
          "then" = [
            {
              action = "input_number.increment";
              data = { };
              target.entity_id = e.input_number.botty_wiederholungen;
            }
          ];
          "else" = [
            {
              action = "input_number.set_value";
              data.value = 1;
              target.entity_id = e.input_number.botty_wiederholungen;
            }
          ];
        }
      ];
    };

    botty_zurueckkehren = {
      alias = "Botty Zurückkehren";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          action = "vacuum.send_command";
          data.command = "app_pause";
          target.entity_id = e.vacuum.botty;
        }
        {
          delay = {
            hours = 0;
            minutes = 0;
            seconds = 2;
            milliseconds = 0;
          };
        }
        {
          action = "vacuum.send_command";
          data.command = "app_charge";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_pausieren = {
      alias = "Botty Pausieren";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          action = "vacuum.send_command";
          data.command = "app_pause";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_fortsetzen = {
      alias = "Botty Fortsetzen";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          action = "vacuum.send_command";
          data.command = "resume_zoned_clean";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_main_brush_reset = {
      alias = "Botty main brush reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "main_brush_work_time" ];
          };
        }
      ];
    };

    botty_side_brush_reset = {
      alias = "Botty side brush reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "side_brush_work_time" ];
          };
        }
      ];
    };

    botty_filter_reset = {
      alias = "Botty filter reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "filter_work_time" ];
          };
        }
      ];
    };

    botty_sensor_cleaning_reset = {
      alias = "Botty sensor cleaning reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "sensor_dirty_time" ];
          };
        }
      ];
    };
  };
}
