using System;
using System.Collections.Generic;
using System.Globalization;
using System.Drawing;
using System.Windows.Forms;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.DatabaseServices;
using CadApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace AlcAssignUi
{
    public sealed class LayerChoice
    {
        public string Name;
        public double Width;
        public LayerChoice(string name, double width) { Name = name; Width = width; }
    }

    public sealed class Picker : Form
    {
        readonly List<LayerChoice> layers;
        readonly DataGridView grid = new DataGridView();
        readonly TextBox width = new TextBox();
        readonly Label status = new Label();
        readonly Label pageLabel = new Label();
        readonly Button previous = new Button();
        readonly Button next = new Button();
        int page;
        public LayerChoice Choice { get; private set; }
        public int VisibleCount { get { return grid.Rows.Count; } }
        public string SelectedName { get { return Selected == null ? null : Selected.Name; } }
        LayerChoice Selected { get { return grid.CurrentRow == null || page * 9 + grid.CurrentRow.Index >= layers.Count ? null : layers[page * 9 + grid.CurrentRow.Index]; } }

        public Picker(List<LayerChoice> items, string current)
        {
            layers = items;
            Text = "VVA - Chon layer va PLINEWID";
            ClientSize = new Size(720, 405);
            MinimumSize = MaximumSize = Size;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            KeyPreview = true;
            Font = new System.Drawing.Font("Segoe UI", 10);
            var hint = new Label { Text = "Bam 1-9 de chon dong; Enter / Space de xac nhan; Esc de huy.", AutoSize = true, Location = new Point(12, 12) };
            grid.SetBounds(12, 40, 696, 255);
            grid.ReadOnly = true; grid.AllowUserToAddRows = grid.AllowUserToDeleteRows = false;
            grid.AllowUserToResizeRows = false; grid.RowHeadersVisible = false;
            grid.MultiSelect = false; grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
            grid.ScrollBars = ScrollBars.None;
            grid.ColumnHeadersHeight = 26; grid.RowTemplate.Height = 25;
            grid.Columns.Add("number", "So"); grid.Columns.Add("layer", "Layer"); grid.Columns.Add("width", "PLINEWID");
            grid.Columns[0].FillWeight = 8; grid.Columns[1].FillWeight = 70; grid.Columns[2].FillWeight = 22;
            foreach (DataGridViewColumn c in grid.Columns) c.SortMode = DataGridViewColumnSortMode.NotSortable;
            grid.SelectionChanged += (s, e) => SyncWidth();
            previous.Text = "< Truoc"; previous.SetBounds(12, 304, 90, 30);
            next.Text = "Sau >"; next.SetBounds(108, 304, 90, 30);
            previous.Click += (s, e) => ChangePage(-1); next.Click += (s, e) => ChangePage(1);
            pageLabel.SetBounds(210, 310, 170, 24);
            var widthLabel = new Label { Text = "PLINEWID:", Location = new Point(390, 311), AutoSize = true };
            width.SetBounds(480, 306, 100, 28);
            var ok = new Button { Text = "OK", Location = new Point(588, 304), Size = new Size(120, 30) };
            ok.Click += (s, e) => Submit();
            status.SetBounds(12, 343, 696, 50);
            Controls.AddRange(new Control[] { hint, grid, previous, next, pageLabel, widthLabel, width, ok, status });
            int initial = items.FindIndex(x => string.Equals(x.Name, current, StringComparison.OrdinalIgnoreCase));
            if (initial < 0) initial = 0;
            page = initial / 9;
            FillPage(initial % 9);
            Shown += (s, e) => grid.Focus();
        }

        void FillPage(int row)
        {
            grid.Rows.Clear();
            int count = Math.Min(9, layers.Count - page * 9);
            for (int i = 0; i < count; i++)
            {
                var item = layers[page * 9 + i];
                grid.Rows.Add(i + 1, item.Name, item.Width < 0 ? "?" : item.Width.ToString("0.###", CultureInfo.InvariantCulture));
            }
            if (count > 0) grid.CurrentCell = grid.Rows[Math.Min(row, count - 1)].Cells[0];
            pageLabel.Text = "Trang " + (page + 1) + " / " + Math.Max(1, (layers.Count + 8) / 9);
            previous.Enabled = page > 0; next.Enabled = (page + 1) * 9 < layers.Count;
            SyncWidth();
        }
        void SyncWidth()
        {
            var selected = Selected;
            width.Text = selected == null || selected.Width < 0 ? "" : selected.Width.ToString("0.###############", CultureInfo.InvariantCulture);
            status.Text = selected != null && selected.Width < 0 ? "Layer chua co PLINEWID: nhap gia tri (cho phep 0)." : "";
        }
        public void ChangePage(int delta)
        {
            int target = page + delta;
            if (target < 0 || target * 9 >= layers.Count) return;
            page = target; FillPage(0); grid.Focus();
        }
        public bool SelectShortcut(int number)
        {
            if (number < 1 || number > VisibleCount) return false;
            grid.CurrentCell = grid.Rows[number - 1].Cells[0];
            SyncWidth(); grid.Focus(); return true;
        }
        public bool Submit()
        {
            double value;
            string text = width.Text.Trim().Replace(',', '.');
            if (Selected == null || !double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value)
                || double.IsNaN(value) || double.IsInfinity(value) || value < 0)
            { status.Text = "PLINEWID phai la so >= 0."; width.Focus(); return false; }
            Choice = new LayerChoice(Selected.Name, value);
            DialogResult = DialogResult.OK; Close(); return true;
        }
        public bool HandleShortcut(Keys key)
        {
            Keys code = key & Keys.KeyCode;
            if ((key & Keys.Modifiers) != Keys.None) return false;
            if (code == Keys.Escape) { DialogResult = DialogResult.Cancel; Close(); return true; }
            if (code == Keys.Enter || code == Keys.Space) { Submit(); return true; }
            // Clicking/Tab into PLINEWID keeps digit keys available for editing it.
            if (width.ContainsFocus) return false;
            if (code >= Keys.D1 && code <= Keys.D9) { SelectShortcut(code - Keys.D1 + 1); return true; }
            if (code >= Keys.NumPad1 && code <= Keys.NumPad9) { SelectShortcut(code - Keys.NumPad1 + 1); return true; }
            if (code == Keys.PageDown) { ChangePage(1); return true; }
            if (code == Keys.PageUp) { ChangePage(-1); return true; }
            return false;
        }
        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        { return HandleShortcut(keyData) || base.ProcessCmdKey(ref msg, keyData); }
    }

    public static class Entry
    {
        [LispFunction("ALC-ASSIGN-UI")]
        public static ResultBuffer Show(ResultBuffer input)
        {
            if (input == null) return null;
            var values = input.AsArray();
            if (values.Length < 3 || values.Length % 2 != 1) return null;
            var layers = new List<LayerChoice>();
            for (int i = 1; i < values.Length; i += 2)
                layers.Add(new LayerChoice((string)values[i].Value, Convert.ToDouble(values[i + 1].Value, CultureInfo.InvariantCulture)));
            using (var form = new Picker(layers, (string)values[0].Value))
            {
                if (CadApp.ShowModalDialog(form) != DialogResult.OK || form.Choice == null) return null;
                return new ResultBuffer(new TypedValue((int)LispDataType.Text, form.Choice.Name),
                                        new TypedValue((int)LispDataType.Double, form.Choice.Width));
            }
        }
    }
}
