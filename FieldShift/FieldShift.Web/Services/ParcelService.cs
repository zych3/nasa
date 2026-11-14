using System.Text;
using System.Xml.Linq;
using FieldShift.Web.Data;

namespace FieldShift.Web.Services;

public class ParcelService(HttpClient http)
{
    private const string Url = "https://mapy.geoportal.gov.pl/openLSgp/geocode";
    public async Task<GeocodeResult?> GetAddressPosition(string address)
    {
        var doc = BuildRequest(address);
        var res = await http.PostAsync(Url, new StringContent(doc.ToString(), Encoding.UTF8, "aplication/xml"));
        res.EnsureSuccessStatusCode();
        var content = await res.Content.ReadAsStringAsync();
        return GeocodeParser.Parse(content);
    }

    private XDocument BuildRequest(string address)
    {
        XNamespace xls = "http://www.opengis.net/xls";
        return new XDocument(
            new XElement(xls + "XLS", new XAttribute("version", "1.2"),
                new XElement(xls + "RequestHeader"),
                new XElement(xls + "Request",
                    new XAttribute("methodName", "GeocodeRequest"),
                    new XAttribute("requestID", "1"),
                    new XAttribute("version", "1.2"),
                    new XElement(xls + "GeocodeRequest",
                        new XElement(xls + "Address", new XAttribute("countryCode", "PL"),
                            new XElement(xls + "freeFormAddress", address))))));
    }
}