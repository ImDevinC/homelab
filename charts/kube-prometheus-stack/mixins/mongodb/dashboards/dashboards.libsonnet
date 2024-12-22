{
  grafanaDashboards+:: {
    'collections_overview': (import 'MongoDB_Collections_Overview.json'),
    'in_memory_details': (import 'MongoDB_InMemory_Details.json'),
    'instance_summary': (import 'MongoDB_Instance_Summary.json'),
    'instance_overview': (import 'MongoDB_Instances_Overview.json'),
    'replicaset_summary': (import 'MongoDB_ReplSet_Summary.json')
  },
}
