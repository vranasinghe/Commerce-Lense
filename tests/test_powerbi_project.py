"""Repository-contract checks; these do not substitute for Desktop refresh."""
import json
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ReportContractTests(unittest.TestCase):
    def test_pages_and_container_ids_preserved(self):
        original=json.loads((ROOT/'docs/baseline/report-layout.json').read_text())
        expected={s['displayName']:{json.loads(v['config'])['name'] for v in s['visualContainers']} for s in original['sections']}
        actual={}
        for page in (ROOT/'powerbi/CommerceLens.Report/definition/pages').glob('*/page.json'):
            name=json.loads(page.read_text())['displayName']
            actual[name]={json.loads(v.read_text())['name'] for v in page.parent.glob('visuals/*/visual.json')}
        self.assertEqual(actual,expected)
    def test_measure_references_exist(self):
        measures=json.loads((ROOT/'powerbi/measures.json').read_text())
        found=set()
        for path in (ROOT/'powerbi/CommerceLens.Report').rglob('visual.json'):
            visual=json.loads(path.read_text())['visual']
            for role in visual.get('query',{}).get('queryState',{}).values():
                for p in role.get('projections',[]):
                    field=p['field']
                    self.assertNotIn('Aggregation',field)
                    if 'Measure' in field:
                        name=field['Measure']['Property'];self.assertIn(name,measures);found.add(name)
        self.assertIn('Average Order Value BRL',found)
        self.assertIn('Average Customer Rating',found)
    def test_resource_paths_exist(self):
        root=ROOT/'powerbi/CommerceLens.Report'
        report=json.loads((root/'definition/report.json').read_text())
        for package in report['resourcePackages']:
            for item in package['items']:
                self.assertTrue((root/'StaticResources'/package['name']/item['path']).is_file(),item['path'])
    def test_one_to_many_order_and_common_date_contract(self):
        relationships=(ROOT/'powerbi/CommerceLens.SemanticModel/definition/relationships.tmdl').read_text()
        self.assertNotIn('toCardinality: many',relationships)
        self.assertIn('toCardinality: one',relationships)
        self.assertIn('toColumn: dim_date.full_date',relationships)
if __name__=='__main__':unittest.main()
