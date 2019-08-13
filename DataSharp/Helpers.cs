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
    }
}
