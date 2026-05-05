{ ... }:
# Demonstrative end-to-end intents for closest_intent. Speak any of the
# `Test_*` phrases at the Assist pipeline; the response should confirm
# the system caught what you said.
#
# Exercised features:
#   1. Plain pattern, no slots → fuzzy on the whole phrase.
#   2. {area} slot → fuzzy slot-value resolution against HA's area registry.
#   3. {name} slot → same, against exposed entity friendly names.
#   4. Custom slot list (`bewohner`) declared in custom_sentences.
#   5. Custom expansion rule (`<test_gruss>`) declared in custom_sentences.
#   6. Built-in HA expansion rule (`<stelle>`) referenced from custom_sentences.
{
  hass.voice.intents = {
    Test_Plain = [ "Test eins" ];
    Test_Area = [ "Test zwei im {area}" ];
    Test_Name = [ "Test drei mit {name}" ];
  };

  hass.voice.custom_sentences.closest_intent_tests = {
    language = "de";
    intents = {
      Test_CustomList.data = [
        { sentences = [ "Test vier ist {bewohner} zu Hause" ]; }
      ];
      Test_CustomRule.data = [
        { sentences = [ "<test_gruss> Test fünf" ]; }
      ];
      Test_BuiltinRule.data = [
        { sentences = [ "<stelle> Test sechs" ]; }
      ];
    };
    lists.bewohner.values = [
      { "in" = "Charlotte"; out = "person.charlotte"; }
    ];
    expansion_rules.test_gruss = "(hallo|guten tag|moin)";
  };

  hass.voice.intent_scripts = {
    Test_Plain.speech.text = "Test eins erkannt.";
    Test_Area.speech.text = "Test zwei: Bereich {{ area }}.";
    Test_Name.speech.text = "Test drei: Entity {{ name }}.";
    Test_CustomList.speech.text = "Test vier: Person {{ bewohner }}.";
    Test_CustomRule.speech.text = "Test fünf erkannt.";
    Test_BuiltinRule.speech.text = "Test sechs erkannt.";
  };
}
