{ config, ... }:
{
  hass.voice.intents = {
    EinkaufAdd = {
      sentences = [
        "(setze|setz|pack|tu|schreib) {item} auf (die|meine) Einkaufsliste"
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

    ToDoAdd = {
      sentences = [
        # One per verb: closest_intent expands a pattern into at most 16
        # forms, and as one pattern "tu …" and "schreib …" were cut off.
        "setze {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "setz {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "pack {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "tu {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
        "schreib {item} auf (die|meine) (ToDo|To-Do|To Do)-Liste"
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
