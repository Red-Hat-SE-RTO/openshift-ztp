# Performance Tuning

This says performance tuning, but it's more of a how to run leaner workloads.

## Hub Cluster

- **Set the Klusterlet CR on the Hub cluster to Hosted mode** which will run the Klusterlet workloads on the Hub, not on the Spokes!  Value `.spec.deployOption.mode: "Hosted"`
  `oc patch klusterlet klusterlet --type=json -p='[{"op": "replace", "path": "/spec/deployOption/mode", "value": "Hosted"}]'`

- Set the MulticlusterEngine availabilityConfig to Basic [default]

## Spoke Cluster

## All Clusters

- **Set OperatorHub CatalogSources to slower sync rates, eg 24h**
  `oc get catalogsources -n openshift-marketplace -o name | sed -e 's/.*\///g' | xargs -I {} oc patch catalogsource -n openshift-marketplace {} --type=json -p='[{"op": "replace", "path": "/spec/updateStrategy/registryPoll/interval", "value": "1440m0s"}]'`
