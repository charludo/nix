{ ... }:
# Voice intents for adding items to shopping / to-do lists.
#
# `{item}` is a wildcard — captures arbitrary spoken text.
{
  hass.voice = {
    Einkauf_Add = {
      sentences = [
        "(setze|pack|tu|schreib) {item} auf (die|meine) Einkaufsliste"
        "{item} auf die Einkaufsliste"
        "Einkaufsliste {item}"
        "Füge {item} zur Einkaufsliste hinzu"
      ];
      lists.item.wildcard = true;
      script = {
        speech.text = ''"{{ item }}" hinzugefügt.'';
        action = {
          service = "todo.add_item";
          data.item = "{{ item }}";
          target.entity_id = "todo.shopping_list";
        };
      };
    };

    ToDo_Add = {
      sentences = [
        "(setze|pack|tu|schreib) {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "{item} auf die ToDo-Liste"
        "ToDo-Liste {item}"
      ];
      script = {
        speech.text = ''"{{ item }}" hinzugefügt.'';
        action = {
          service = "todo.add_item";
          data.item = "{{ item }}";
          target.entity_id = "todo.todo_liste";
        };
      };
    };
  };
}
