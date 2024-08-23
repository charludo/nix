{ config, pkgs, ... }:
let
  cellolesson = pkgs.writeShellApplication {
    name = "cellolesson";
    runtimeInputs = [ pkgs.qpwgraph pkgs.calf ];
    text = ''
      ${pkgs.calf}/bin/calfjackhost --load "${config.home.homeDirectory}/.config/calf/cellolesson.xml" &
      ${pkgs.qpwgraph}/bin/qpwgraph -a "${config.home.homeDirectory}/.config/qpwgraph/cellolesson.qpwgraph"
    '';
  };
in
{
  home.packages = with pkgs;
    [
      ardour
      qpwgraph
      calf
    ] ++ [ cellolesson ];

  xdg.desktopEntries."cellolesson" = {
    name = "Cello Lesson";
    icon = "audio-recorder";
    type = "Application";
    comment = "Configure JACK for remote music lesson streaming";
    terminal = false;
    startupNotify = true;
    exec = "${cellolesson}/bin/cellolesson";
    categories = [ "Audio" "Midi" "Mixer" "Music" ];
  };

  home.file.".config/calf/cellolesson.xml".text = /* xml */ ''
    <?xml version="1.1" encoding="utf-8"?>
    <rack><plugin type="sidechaincompressor" instance-name="Sidechain Compressor" input-index="1" output-index="1">
    <preset bank="0" program="0" plugin="sidechaincompressor" name="">
      <param name="bypass" value="0" />
      <param name="level_in" value="1" />
      <param name="meter_in" value="0.000208108" />
      <param name="meter_out" value="0.000208108" />
      <param name="clip_in" value="0" />
      <param name="clip_out" value="0" />
      <param name="threshold" value="0.00160858" />
      <param name="ratio" value="4.29497e+09" />
      <param name="attack" value="96.9113" />
      <param name="release" value="75.9196" />
      <param name="makeup" value="1" />
      <param name="knee" value="1.89737" />
      <param name="detection" value="0" />
      <param name="stereo_link" value="1" />
      <param name="compression" value="1" />
      <param name="sc_mode" value="0" />
      <param name="f1_freq" value="250" />
      <param name="f2_freq" value="4500" />
      <param name="f1_level" value="1" />
      <param name="f2_level" value="1" />
      <param name="sc_listen" value="0" />
      <param name="f1_active" value="0" />
      <param name="f2_active" value="0" />
      <param name="sc_route" value="1" />
      <param name="sc_level" value="3.31268" />
      <param name="mix" value="1" />
    </preset>
    </plugin>
    <plugin type="eq5" instance-name="Equalizer 5 Band" input-index="5" output-index="3">
    <preset bank="0" program="0" plugin="eq5" name="">
      <param name="bypass" value="0" />
      <param name="level_in" value="0.165856" />
      <param name="level_out" value="2.53854" />
      <param name="meter_inL" value="3.4516e-05" />
      <param name="meter_inR" value="3.4516e-05" />
      <param name="meter_outL" value="8.76202e-05" />
      <param name="meter_outR" value="8.76202e-05" />
      <param name="clip_inL" value="0" />
      <param name="clip_inR" value="0" />
      <param name="clip_outL" value="0" />
      <param name="clip_outR" value="0" />
      <param name="ls_active" value="0" />
      <param name="ls_level" value="1" />
      <param name="ls_freq" value="100" />
      <param name="ls_q" value="0.707" />
      <param name="hs_active" value="0" />
      <param name="hs_level" value="1" />
      <param name="hs_freq" value="5000" />
      <param name="hs_q" value="0.707" />
      <param name="p1_active" value="0" />
      <param name="p1_level" value="1" />
      <param name="p1_freq" value="250" />
      <param name="p1_q" value="1" />
      <param name="p2_active" value="0" />
      <param name="p2_level" value="1" />
      <param name="p2_freq" value="1000" />
      <param name="p2_q" value="1" />
      <param name="p3_active" value="0" />
      <param name="p3_level" value="1" />
      <param name="p3_freq" value="4000" />
      <param name="p3_q" value="1" />
      <param name="individuals" value="1" />
      <param name="zoom" value="0.25" />
      <param name="analyzer" value="0" />
      <param name="analyzer_mode" value="1" />
    </preset>
    </plugin>
    <plugin type="reverb" instance-name="Reverb" input-index="7" output-index="5">
    <preset bank="0" program="0" plugin="reverb" name="">
      <param name="meter_inL" value="0.000155841" />
      <param name="meter_inR" value="0.000155841" />
      <param name="clip_outL" value="0" />
      <param name="decay_time" value="0.497166" />
      <param name="hf_damp" value="5000" />
      <param name="room_size" value="1" />
      <param name="diffusion" value="0.5" />
      <param name="amount" value="0.174343" />
      <param name="dry" value="0.961927" />
      <param name="predelay" value="0" />
      <param name="bass_cut" value="300" />
      <param name="treble_cut" value="5000" />
      <param name="on" value="1" />
      <param name="level_in" value="1" />
      <param name="level_out" value="1" />
      <param name="meter_outL" value="0.000152544" />
      <param name="meter_outR" value="0.000149913" />
      <param name="clip_inL" value="0" />
      <param name="clip_inR" value="0" />
      <param name="clip_outR" value="0" />
    </preset>
    </plugin>
    </rack>
  '';

  home.file.".config/qpwgraph/cellolesson.qpwgraph".text = /* html */ ''
    <!DOCTYPE patchbay>
    <patchbay name="cellolesson" version="0.7.5">
     <items>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Built-in Audio Analog Stereo" port="ALC255 Analog:capture_FR"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Gate Out #1"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Equalizer 5 Band Out #2"/>
       <input node="Multi Source Aggregator" port="Multi Source Aggregator:playback_MONO"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Limiter In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Built-in Audio Analog Stereo" port="ALC255 Analog:capture_FL"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #4"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Gate Out #2"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Reverb In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Multi Source Aggregator" port="Multi Source Aggregator:capture_MONO"/>
       <input node="ZOOM VoiceEngine" port="ZOOM VoiceEngine:input_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Mono Compressor In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Gate In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Limiter In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Gate In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Multi Source Aggregator" port="Multi Source Aggregator:capture_MONO"/>
       <input node="Built-in Audio Analog Stereo" port="ALC255 Analog:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate Out #2"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor Out #1"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Equalizer 5 Band In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X (BT)" port="Razer Barracuda X (BT):capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Gate Out #2"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Gate Out #1"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Reverb In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate Out #2"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Multi Source Aggregator" port="Multi Source Aggregator:capture_MONO"/>
       <input node="Firefox" port="Firefox:input_MONO"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #3"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Multi Source Aggregator" port="Multi Source Aggregator:capture_MONO"/>
       <input node="ZOOM VoiceEngine" port="ZOOM VoiceEngine:input_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Built-in Audio Analog Stereo" port="ALC255 Analog:capture_FR"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="ZOOM VoiceEngine" port="ZOOM VoiceEngine:output_FR"/>
       <input node="Built-in Audio Analog Stereo" port="ALC255 Analog:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Reverb In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Reverb Out #2"/>
       <input node="Multi Source Aggregator" port="Multi Source Aggregator:playback_MONO"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Built-in Audio Analog Stereo" port="ALC255 Analog:capture_FL"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #3"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate Out #1"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Equalizer 5 Band Out #1"/>
       <input node="Multi Source Aggregator" port="Multi Source Aggregator:playback_MONO"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X 2.4 Mono" port="Razer Barracuda X 2.4:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Multi Source Aggregator" port="Multi Source Aggregator:capture_MONO"/>
       <input node="Built-in Audio Analog Stereo" port="ALC255 Analog:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Reverb Out #1"/>
       <input node="Multi Source Aggregator" port="Multi Source Aggregator:playback_MONO"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Gate Out #1"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Gate In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Limiter Out #2"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FR"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Razer Barracuda X (BT)" port="Razer Barracuda X (BT):capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #1"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="ZOOM VoiceEngine" port="ZOOM VoiceEngine:output_FL"/>
       <input node="Built-in Audio Analog Stereo" port="ALC255 Analog:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Limiter In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Limiter Out #1"/>
       <input node="Razer Barracuda X 2.4 Analog Stereo" port="Razer Barracuda X 2.4:playback_FL"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor Out #2"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Equalizer 5 Band In #2"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 1 Mic" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Sidechain Compressor In #4"/>
      </item>
      <item node-type="pipewire" port-type="pipewire-audio">
       <output node="Scarlett Solo (3rd Gen.) Input 2 Inst/Line" port="Scarlett Solo USB:capture_MONO"/>
       <input node="Calf Studio Gear" port="Calf Studio Gear:Reverb In #1"/>
      </item>
     </items>
    </patchbay>
  '';
}
