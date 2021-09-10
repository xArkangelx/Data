using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Management.Automation;
using System.Collections;

namespace DataSharp
{
    [Cmdlet(VerbsCommon.Set, "PropertyValue")]
    public class SetPropertyValue : PSCmdlet
    {
        [Parameter(ValueFromPipeline = true)]
        public PSObject InputObject { get; set; }

        [Parameter(Mandatory = true, Position = 0)]
        public string[] Property { get; set; }

        [Parameter(Position = 1)]
        public object Value { get; set; }

        [Parameter()]
        public string JoinWith { get; set; }

        [Parameter()]
        public object Where { get; set; }

        [Parameter()]
        public string Match { get; set; }

        [Parameter()]
        public SwitchParameter IfUnset { get; set; }

        [Parameter()]
        public SwitchParameter NoClone { get; set; }

        private bool whereIsScriptBlock = false;
        private ScriptBlock whereAsScriptBlock;

        private bool whereIsString = false;
        private string whereAsString;
        private System.Text.RegularExpressions.Regex matchRegex;
        private string[] matchGroupNames;

        private bool valueIsScriptBlock = false;
        private ScriptBlock valueAsScriptBlock;

        protected override void BeginProcessing()
        {
            if (Where is ScriptBlock)
            {
                whereIsScriptBlock = true;
                whereAsScriptBlock = (ScriptBlock)Where;
            }
            else if (Where != null && !String.IsNullOrWhiteSpace(Where.ToString()))
            {
                whereIsString = true;
                whereAsString = Where.ToString();
            }
            if (Value is ScriptBlock)
            {
                valueIsScriptBlock = true;
                valueAsScriptBlock = (ScriptBlock)Value;
            }

            if (Match != null)
            {
                matchRegex = new System.Text.RegularExpressions.Regex(Match, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                matchGroupNames = matchRegex.GetGroupNames();
            }
        }

        protected override void ProcessRecord()
        {
            if (InputObject == null) return;
            PSObject newInputObject;
            if (NoClone.IsPresent)
                newInputObject = Helpers.EnsureHasProperties(InputObject, Property);
            else
                newInputObject = Helpers.CloneObject(InputObject, Property);

            bool setValue = true;
            PSVariable matchVar = new PSVariable("Matches");

            if (whereIsScriptBlock)
            {
                var varList = new List<PSVariable>();
                varList.Add(new PSVariable("_", InputObject));
                varList.Add(matchVar);
                var whereResult = whereAsScriptBlock.InvokeWithContext(null, varList, null);
                setValue = LanguagePrimitives.IsTrue(whereResult);
            }
            else if (whereIsString)
            {
                setValue = false;
                var whereProperty = newInputObject.Properties[whereAsString];
                if (Match != null && whereProperty != null && whereProperty.Value != null)
                {
                    var matchResult = matchRegex.Match(whereProperty.Value.ToString());
                    setValue = matchResult.Success;
                    Hashtable matches = new Hashtable(StringComparer.CurrentCultureIgnoreCase);
                    foreach (string groupName in matchGroupNames)
                    {
                        System.Text.RegularExpressions.Group g = matchResult.Groups[groupName];
                        if (g.Success)
                        {
                            int keyInt;
                            if (Int32.TryParse(groupName, out keyInt))
                                matches.Add(keyInt, g.ToString());
                            else
                                matches.Add(groupName, g.ToString());
                        }
                    }
                    matchVar.Value = matches;
                }
                else
                    setValue = whereProperty != null && LanguagePrimitives.IsTrue(whereProperty.Value);
            }
            if (!setValue)
            {
                WriteObject(newInputObject);
                return;
            }

            object newValue = Value;
            if (valueIsScriptBlock)
            {
                var varList = new List<PSVariable>();
                varList.Add(new PSVariable("_", InputObject));
                varList.Add(matchVar);
                var scriptResult = valueAsScriptBlock.InvokeWithContext(null, varList, null);
                if (scriptResult.Count == 1)
                    newValue = scriptResult[0];
                else
                    newValue = scriptResult;
            }

            foreach (string property in Property)
            {
                if (!IfUnset.IsPresent || Helpers.IsPropertyNullOrWhiteSpace(newInputObject, property))
                {
                    if (JoinWith != null)
                    {
                        var enumValue = LanguagePrimitives.ConvertTo<string[]>(newValue);
                        newValue = string.Join(JoinWith, enumValue);
                    }
                    newInputObject.Properties.Add(new PSNoteProperty(property, newValue));
                }
            }

            WriteObject(newInputObject);
        }
    }
}
