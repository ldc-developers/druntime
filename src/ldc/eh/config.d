module ldc.eh.config;

import rt.config;

package __gshared bool traceContext = true;

shared static this()
{
    if (rt_configOption("traceContext") == "off")
        traceContext = false;
}
