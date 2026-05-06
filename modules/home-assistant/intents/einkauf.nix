{ ... }:
# Voice intents for adding items to shopping / to-do lists.
#
# `{item}` is a wildcard — captures arbitrary spoken text. That requires
# the `lists.item.wildcard = true` declaration, which only works via
# `custom_sentences/` (HA's strict `conversation:` schema rejects `lists`).
#
# Adjust the `target.entity_id` values to match your actual todo entities
# (Settings → Devices & services → To-do lists).
{
  hass.voice.custom_sentences.einkauf = {
    language = "de";
    intents = {
      Einkauf_Add.data = [
        {
          sentences = [
            "(setze|pack|tu|schreib) {item} auf (die|meine) Einkaufsliste"
            "{item} auf die Einkaufsliste"
            "Einkaufsliste {item}"
            "Füge {item} zur Einkaufsliste hinzu"
          ];
        }
      ];
      ToDo_Add.data = [
        {
          sentences = [
            "(setze|pack|tu|schreib) {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
            "{item} auf die ToDo-Liste"
            "ToDo-Liste {item}"
          ];
        }
      ];
    };
    lists.item.wildcard = true;
  };

  hass.voice.intent_scripts = {
    Einkauf_Add = {
      speech.text = ''"{{ item }}" hinzugefügt.'';
      action = {
        service = "todo.add_item";
        data.item = "{{ item }}";
        target.entity_id = "todo.shopping_list";
      };
    };
    ToDo_Add = {
      speech.text = ''"{{ item }}" hinzugefügt.'';
      action = {
        service = "todo.add_item";
        data.item = "{{ item }}";
        target.entity_id = "todo.todo_liste";
      };
    };
  };
}
