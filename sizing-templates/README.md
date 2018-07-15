# Cluster Sizing Templates

The files in this directory are used to define cluster size templates.

You can add additional templates by copying and renaming the templates in this directory.

Cluster size is specified when running the [deploy](../deploy) CLI tool via the ```--cluster_size``` flag. It is expected that the value supplied for that parameter will match the file name of the cluster size template without the file extension (e.g. small -> small.yml) 