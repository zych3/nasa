namespace FieldShift.Web.Data;

public readonly record struct CropId(string Value)
{
    public override string ToString() => Value;
}
