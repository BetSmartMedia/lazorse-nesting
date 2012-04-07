# Lazorse-nesting

![horse in a nest](/BetSmartMedia/lazorse-nesting/raw/master/horsenest.png)

This module can be `@include`ed into a Lazorse application to enable
client-driven inlining of named resources. By client-driven, we mean that the
client specifies a list of related resources as part of the request, and this
extension takes care of inlining those resources into the response data.

## How it works

The client to specifies keys they would like to have inlined into their response
using a query parameter (``inline`` by default). When those keys are seen in the
response data, *and* the value of those keys looks like a URL path (such as the
ones generated by the builtin `@link` helper), the value will be replaced with
the response data of an internally dispatched request against that path.

To see how this looks in practice, check out [this test](/BetSmartMedia/lazorse-nesting/blob/master/test/nesting.test.coffee).