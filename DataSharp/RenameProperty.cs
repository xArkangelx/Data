using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Management.Automation;
using System.Collections;

namespace DataSharp
{
    [Cmdlet(VerbsCommon.Rename, "Property")]
    public class RenameProperty : PSCmdlet
    {
        [Parameter(ValueFromPipeline = true)]
        public PSObject InputObject { get; set; }

        [Parameter(Mandatory = true, Position = 0, ParameterSetName = "Hashtable")]
        public Hashtable Rename { get; set; }

        [Parameter(Mandatory = true, Position = 0, ParameterSetName = "String")]
        public string From { get; set; }

        [Parameter(Mandatory = true, Position = 1, ParameterSetName = "String")]
        public string To { get; set; }

        [Parameter(ValueFromRemainingArguments = true, ParameterSetName = "String")]
        public string[] OtherFromToPairs { get; set; }

        Dictionary<string, string> renameDict = new Dictionary<string, string>();

        protected override void BeginProcessing()
        {
            if (ParameterSetName == "Hashtable")
                foreach (object key in Rename.Keys)
                    renameDict[(string)key] = (string)Rename[key];
            else
                renameDict[From] = To;

            if (OtherFromToPairs != null)
            {
                var actualOtherPairs = OtherFromToPairs.Where(s => s != "+").ToArray();
                if (actualOtherPairs.Length % 2 != 0)
                    ThrowTerminatingError(Helpers.NewInvalidArgumentErrorRecord("OtherFromToPairs must contain an even number of values."));
                for (var i = 0; i < actualOtherPairs.Length; i += 2)
                    renameDict[actualOtherPairs[i]] = actualOtherPairs[i + 1];
            }
        }

        protected override void ProcessRecord()
        {
            if (InputObject == null) return;
            var newObject = new PSObject();
            foreach (var property in InputObject.Properties)
            {
                if (renameDict.ContainsKey(property.Name))
                    newObject.Properties.Add(new PSNoteProperty(renameDict[property.Name], property.Value));
                else
                    newObject.Properties.Add(property);
            }
            WriteObject(newObject);
        }
    }
}
