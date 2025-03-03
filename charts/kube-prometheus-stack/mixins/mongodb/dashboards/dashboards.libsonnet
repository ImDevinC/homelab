{
  grafanaDashboards+:: {
    'collections_overview.json': (import 'MongoDB_Collections_Overview.json'),
    'in_memory_details.json': (import 'MongoDB_InMemory_Details.json'),
    'instance_summary.json': (import 'MongoDB_Instance_Summary.json'),
#    'instance_overview.json': (import 'MongoDB_Instances_Overview.json'),
    'replicaset_summary.json': (import 'MongoDB_ReplSet_Summary.json')
  },
}
