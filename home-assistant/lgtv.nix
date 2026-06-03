let
  mk = path: {
    url = "http://192.168.24.101/${path}";
    method = "GET";
  };
in
{
  services.home-assistant.extraComponents = [ "rest_command" ];

  services.home-assistant.config.rest_command = {
    lgtv_picture_day = mk "picture/day";
    lgtv_picture_night = mk "picture/night";
    lgtv_picture_dolby = mk "picture/dolby";
    lgtv_picture_hdr = mk "picture/hdr";
    lgtv_picture_on = mk "picture/on";
    lgtv_picture_off = mk "picture/off";
    lgtv_up = mk "up";
    lgtv_down = mk "down";
    lgtv_back = mk "back";
    lgtv_enter = mk "enter";
    lgtv_sound_select = mk "sound/select";
    lgtv_settings = mk "settings";
  };
}
