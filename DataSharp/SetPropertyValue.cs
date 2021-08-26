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
        public object Where { get; set; }

        [Parameter()]
        public SwitchParameter IfUnset { get; set; }

        [Parameter()]
        public SwitchParameter NoClone { get; set; }

        [Parameter()]
        public string JoinWith { get; set; }

        private bool whereIsScriptBlock = false;
        private ScriptBlock whereAsScriptBlock;

        private bool whereIsString = false;
        private string whereAsString;

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
                var whereProperty = newInputObject.Properties[whereAsString];
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
