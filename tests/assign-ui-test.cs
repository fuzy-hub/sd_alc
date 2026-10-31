using System;
using System.Collections.Generic;
using System.Reflection;
using System.Windows.Forms;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using AlcAssignUi;

public static class AssignUiTest
{
    [LispFunction("ALC-ASSIGN-UI-TEST")]
    public static ResultBuffer Run(ResultBuffer unused)
    {
        var results = new List<TypedValue>();
        Action<string, bool> check = (name, pass) => results.Add(new TypedValue((int)LispDataType.Text, (pass ? "PASS " : "FAIL ") + name));
        var items = new List<LayerChoice>();
        for (int i = 1; i <= 20; i++) items.Add(new LayerChoice("ALC_Test_" + i, i * 10.0));
        using (var p = new Picker(items, "ALC_Test_12"))
        {
            check("current-layer-opens-correct-page", p.VisibleCount == 9 && p.SelectedName == "ALC_Test_12");
            p.HandleShortcut(Keys.D5);
            check("digit-immediately-selects-row-without-edit-box", p.SelectedName == "ALC_Test_14");
            p.HandleShortcut(Keys.NumPad9);
            check("numpad-immediately-selects-row", p.SelectedName == "ALC_Test_18");
            p.HandleShortcut(Keys.PageDown);
            check("last-page-has-only-two-rows", p.VisibleCount == 2 && p.SelectedName == "ALC_Test_19");
            p.HandleShortcut(Keys.D9);
            check("out-of-range-shortcut-does-not-change-selection", p.SelectedName == "ALC_Test_19");
            p.HandleShortcut(Keys.D2);
            check("last-page-shortcuts-use-local-1-through-9", p.SelectedName == "ALC_Test_20");
            p.HandleShortcut(Keys.PageUp);
            check("page-up-restores-nine-row-page", p.VisibleCount == 9 && p.SelectedName == "ALC_Test_10");
            p.HandleShortcut(Keys.D7); p.HandleShortcut(Keys.Space);
            check("Space-confirms-selected-layer-and-synced-width", p.Choice != null && p.Choice.Name == "ALC_Test_16" && p.Choice.Width == 160.0);
        }
        using (var p = new Picker(items, "ALC_Test_1"))
        {
            bool all = true;
            for (int i = 1; i <= 9; i++) { p.HandleShortcut(Keys.D1 + i - 1); all &= p.SelectedName == "ALC_Test_" + i; }
            check("all-nine-digit-shortcuts-select-exact-row", all);
            p.HandleShortcut(Keys.D1); p.HandleShortcut(Keys.Enter);
            check("Enter-confirms-current-first-row", p.Choice != null && p.Choice.Name == "ALC_Test_1" && p.Choice.Width == 10.0);
        }
        using (var p = new Picker(items, "ALC_Test_1"))
        {
            p.HandleShortcut(Keys.D3); p.HandleShortcut(Keys.Escape);
            check("Escape-cancels-without-returning-choice", p.Choice == null && p.DialogResult == DialogResult.Cancel);
        }
        using (var p = new Picker(new List<LayerChoice> { new LayerChoice("ALC_Unknown", -1) }, "ALC_Unknown"))
        {
            check("unknown-width-rejects-confirmation", !p.Submit() && p.Choice == null);
            var field = (TextBox)typeof(Picker).GetField("width", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(p);
            field.Text = "-1"; bool negative = !p.Submit();
            field.Text = "NaN"; bool nan = !p.Submit();
            field.Text = "Infinity"; bool infinity = !p.Submit();
            check("invalid-widths-rejected", negative && nan && infinity);
            field.Text = "125.5";
            check("edited-width-confirmed", p.Submit() && p.Choice != null && p.Choice.Width == 125.5);
        }
        using (var p = new Picker(new List<LayerChoice> { new LayerChoice("ALC_Zero", 0) }, "ALC_Zero"))
        {
            p.HandleShortcut(Keys.Space);
            check("zero-width-remains-supported", p.Choice != null && p.Choice.Width == 0);
        }
        return new ResultBuffer(results.ToArray());
    }
}
