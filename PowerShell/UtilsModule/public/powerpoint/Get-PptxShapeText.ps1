function Get-PptxShapeText {

    [CmdletBinding()]
    [OutputType([string])]
    param($Shape)

    # Grouped shapes
    $text = ''
    if ($Shape.Type -eq 6) {
        foreach ($item in $Shape.GroupItems) {
            $text += Get-PptxShapeText $item
        }
        return $text
    }

    # Normal text
    if ($Shape.HasTextFrame -and $Shape.TextFrame.HasText) {
        $text += $Shape.TextFrame.TextRange.Text
    }

    # Tables
    if ($Shape.HasTable) {
        $table = $Shape.Table

        for ($r = 1; $r -le $table.Rows.Count; $r++) {
            for ($c = 1; $c -le $table.Columns.Count; $c++) {
                $text +=    $table.Cell($r, $c).Shape.TextFrame.TextRange.Text
            }
        }
    }
    return $text
}
