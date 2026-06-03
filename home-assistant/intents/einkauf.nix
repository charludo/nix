{ config, ... }:
{
  hass.voice.intents = {
    Einkauf_Add = {
      sentences = [
        "[setze|setz|pack|tu|schreib] {item} auf (die|meine) Einkaufsliste"
        "Einkaufsliste {item}"
        "Füge {item} zur Einkaufsliste hinzu"
      ];
      lists.item.wildcard = true;
      script = {
        speech.text = ''"{{ item }}" hinzugefügt.'';
        action = [
          {
            action = "todo.add_item";
            data.item = "{{ item }}";
            target.entity_id = config.hass.shopping.todoEntity;
          }
        ];
      };
    };

    ToDo_Add = {
      sentences = [
        "(setze|setz|pack|tu|schreib) {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "ToDo-Liste {item}"
        "Füge {item} zur ToDo-Liste hinzu"
      ];
      script = {
        speech.text = ''"{{ item }}" auf ToDo-Liste gesetzt.'';
        action = [
          {
            action = "todo.add_item";
            data.item = "{{ item }}";
            target.entity_id = "todo.todo_liste";
          }
        ];
      };
    };
  };
}
