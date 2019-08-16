using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Management.Automation;

namespace DataSharp
{
    class Helpers
    {
        public static ErrorRecord NewInvalidArgumentErrorRecord(string Message)
        {
            return new ErrorRecord(new Exception(Message), "", ErrorCategory.InvalidArgument, null);
        }

        public static PSObject CloneObject(PSObject BaseObject, string[] AddProperties)
        {
            PSObject newObject = new PSObject();
            foreach (var property in BaseObject.Properties)
            {
                if (property is PSNoteProperty)
                    newObject.Properties.Add(property);
                else
                    newObject.Properties.Add(new PSNoteProperty(property.Name, property.Value));
            }
            if (AddProperties == null)
                return newObject;
            foreach (string propertyName in AddProperties)
            {
                if (newObject.Properties[propertyName] == null)
                    newObject.Properties.Add(new PSNoteProperty(propertyName, null));
            }
            return newObject;
        }

        public static PSObject EnsureHasProperties(PSObject BaseObject, string[] AddProperties)
        {
            foreach (string propertyName in AddProperties)
            {
                if (BaseObject.Properties[propertyName] == null)
                    BaseObject.Properties.Add(new PSNoteProperty(propertyName, null));
            }
            return BaseObject;
        }
    }
}
