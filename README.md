# MMSCGImageMetadataWrapper
Wrap CGImage's Metadata dictionary.  

* Translates the CFDictionary into a NSMutableDictionary
* Lets you set / get image dates
* Lets you set / get GPS dates
* Lets you set / get CLLocation and coordinates.
* Get a timezone based on the internal location data with a timezone provider.  See [https://github.com/mahyar/split-up-timezone-mapper]() for one provider you can use.

Everything else you will have to edit the mutable dictionary itself.

This doesn't check os versions or types, so you might get errors or empty dictionaries
