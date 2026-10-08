alc_patterns : dialog {
  label = "ALC - Select hatch pattern";
  : row {
    : list_box {
      key = "patterns";
      label = "Patterns";
      width = 24;
      height = 20;
      fixed_width = true;
      multiple_select = false;
    }
    : column {
      : image {
        key = "preview";
        width = 38;
        height = 16;
        fixed_width = true;
        fixed_height = true;
        color = 0;
      }
      : text { key = "description"; width = 42; }
      : text { label = "Schematic preview at current angle"; }
    }
  }
  ok_cancel;
}
