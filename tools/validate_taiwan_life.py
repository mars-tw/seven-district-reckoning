"""Validate authored content and citations. This is not a gameplay test."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CHECKS = 0


def check(condition: bool, message: str) -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        raise AssertionError(message)


def unique(rows: list[dict], label: str, field: str = 'id') -> dict[str, dict]:
    ids = [row[field] for row in rows]
    check(len(ids) == len(set(ids)), f'{label}: duplicate identifier')
    check(all(isinstance(key, str) and key for key in ids), f'{label}: blank identifier')
    return dict(zip(ids, rows))


def validate() -> dict:
    data = json.loads((ROOT / 'godot/data/taiwan_life.json').read_text(encoding='utf-8'))
    research = json.loads((ROOT / 'assets/provenance/taiwan-cultural-research-v04.json').read_text(encoding='utf-8'))
    activity_data = json.loads((ROOT / 'godot/data/taiwan_activities.json').read_text(encoding='utf-8'))
    activities = unique(activity_data['activities'], 'culture activities')
    check(data['schema_version'] == 1 and research['schema_version'] == 1, 'schema version')
    check(data['fictional'] is True, 'fictional status')
    check(data['choice_steps_mode'] == 'suffix_after_prefix', 'choice append contract')
    check(data['timers_mode'] == 'active_job_seconds_pause_with_game', 'paused timer contract')
    stations = unique(data['stations'], 'stations')
    characters = unique(data['characters'], 'characters')
    foods = unique(data['foods'], 'foods')
    items = unique(data['items'], 'items')
    missions = unique(data['missions'], 'missions')
    templates = unique(data['delivery_templates'], 'templates')
    sources = unique(research['sources'], 'sources', 'source_id')
    check(len(stations) >= 16, 'station coverage')
    check(len(foods) >= 12, 'food variety')
    check(len(characters) >= 8 and len(missions) >= 16, 'character chapter coverage')
    check(len(templates) >= 18, 'repeatable delivery coverage')
    check(len(sources) >= 45, 'read primary source count')
    categories = Counter(t['category'] for t in templates.values())
    check(all(categories[c] >= 6 for c in ['food', 'convenience', 'parcel']), 'six templates per delivery kind')
    check(len({s['url'] for s in sources.values()}) == len(sources), 'sources must use distinct canonical URLs')
    check(research['source_count'] == len(sources), 'source manifest count')
    topics = {topic for s in sources.values() for topic in s['topic']}
    check(len(topics) >= 18 and research['topic_count'] == len(topics), 'source topic coverage')
    check(research['major_theme_count'] == len(research['major_themes']) >= 18, 'major theme coverage')
    for sid, source in sources.items():
        host = urlparse(source['url']).hostname or ''
        check(source['url'].startswith('https://'), f'{sid}: HTTPS source')
        check(host.endswith('.gov.tw') or host in ['media.taiwan.net.tw', 'www.taiwan.net.tw', 'www.taichung.travel', 'travel.taichung.gov.tw', 'www.taichungjazzfestival.tw', 'help.shopee.tw', 'www.ibon.com.tw', 'www.family.com.tw', 'nevent.family.com.tw', 'www.7-11.com.tw', 'www.taichung-go.tw'], f'{sid}: unsupported publisher domain')
        check(source['read_confirmed'] is True and source['primary_source'] is True, f'{sid}: unconfirmed primary read')
        check(source['read_method'] in ['web_open_content', 'http_html_text', 'http_pdf_text'], f'{sid}: read method')
        check(bool(source['publisher']) and bool(source['observed_facts']) and bool(source['topic']), f'{sid}: missing research substance')
        check(source['licensed_media'] is False and source['media_downloaded'] is False, f'{sid}: borrowed media unexpectedly included')
        check(research['accessed'] <= source['accessed'] <= research.get('last_reviewed', research['accessed']), f'{sid}: access date outside research/review range')
        check(all(source.get(key) is None or bool(re.fullmatch(r'\d{4}-\d{2}-\d{2}', source[key])) for key in ['published_date', 'updated_date']), f'{sid}: source date format')
        check(all(mid in missions or mid in templates for mid in source['implemented_feature']['data_ids']), f'{sid}: dead feature reference')
        check(all(aid in activities for aid in source['implemented_feature'].get('activity_ids', [])), f'{sid}: dead culture activity reference')
    anchors = {
        'market_square': ('market', [-270, -270]), 'night_market': ('night_market', [270, -270]),
        'daily_store': ('convenience', [270, 0]), 'orange_parcel': ('parcel_hub', [270, 270]),
        'community_green': ('greenway', [0, 270]), 'river_walk': ('river', [-270, 270]),
        'old_arcade': ('heritage', [-270, 0]), 'creative_lane': ('creative', [0, -270]),
    }
    check(data['world_bounds'] == [-400, -400, 400, 400], '800 m world contract')
    for sid, (region, position) in anchors.items():
        check(sid in stations and stations[sid]['position'] == position and stations[sid]['region'] == region, f'{sid}: map anchor differs from agreed contract')
    region_centers = {region: position for region, position in anchors.values()}
    for sid, station in stations.items():
        check(station['region'] in region_centers, f'{sid}: unknown region')
        pos = station['position']
        check(len(pos) == 2 and all(isinstance(n, (int, float)) for n in pos), f'{sid}: XZ position')
        check(all(-400 < n < 400 for n in pos), f'{sid}: outside map')
        center = region_centers[station['region']]
        check(all(abs(pos[i] - center[i]) <= 15 for i in [0, 1]), f'{sid}: station not in reserved clearance square')
        hours = station['opening_hours']
        check(len(hours) == 2 and 0 <= hours[0] < hours[1] <= 24, f'{sid}: opening hours')
        check(station['npc_id'] == '' or station['npc_id'] in characters, f'{sid}: NPC reference')
    check(len({tuple(s['position']) for s in stations.values()}) == len(stations), 'overlapping station anchors')
    for fid, food in foods.items():
        check(fid in items and items[fid]['kind'] == 'food', f'{fid}: missing food inventory item')
        check(food['fictional_recipe'] is True and bool(food['flavor']) and bool(food['handling']), f'{fid}: fictional recipe declaration')
    for cid, character in characters.items():
        check(character['fictional'] is True and isinstance(character['age'], int) and character['age'] >= 18, f'{cid}: adult original character')
        check(character['home_station'] in stations and stations[character['home_station']]['npc_id'] == cid, f'{cid}: home station')
        check((ROOT / 'godot/assets/models' / (character['appearance_key'] + '.glb')).is_file(), f'{cid}: model does not exist')
        check(character['appearance_variant'] == '' or bool(re.fullmatch('[0-9a-f]{6}', character['appearance_variant'])), f'{cid}: optional color variant')
        chapter_ids = character['mission_ids']
        check(len(chapter_ids) >= 2 and len(set(chapter_ids)) == len(chapter_ids), f'{cid}: character needs two unique chapters')
        check(all(mid in missions and missions[mid]['npc_id'] == cid for mid in chapter_ids), f'{cid}: mission ownership')
        check(chapter_ids[0] in missions[chapter_ids[1]]['prerequisites'], f'{cid}: second chapter lacks first chapter causality')
        check(len(character['arc_dialogue']) >= 3 and len(set(character['arc_dialogue'])) >= 3, f'{cid}: distinct progression dialogue')
    visiting, visited = set(), set()
    def visit(mid: str) -> None:
        check(mid not in visiting, f'{mid}: prerequisite cycle')
        if mid in visited: return
        visiting.add(mid)
        for prerequisite in missions[mid]['prerequisites']:
            check(prerequisite in missions, f'{mid}: unknown prerequisite')
            visit(prerequisite)
        visiting.remove(mid); visited.add(mid)
    for mid in missions: visit(mid)
    route_count = 0
    parcel_route_count = 0
    used_targets = set()
    used_foods = set()
    for mid, job in {**missions, **templates}.items():
        check(job['reward']['cash'] >= 0 and job['reward']['trust'] >= 0, f'{mid}: reward')
        check(isinstance(job['limit_seconds'], int) and job['limit_seconds'] >= 0, f'{mid}: time limit')
        check(all(sid in sources for sid in job['source_ids']), f'{mid}: unknown research citation')
        check(bool(job['dialogue']) and bool(job['completion_dialogue']) and bool(job['failure_dialogue']), f'{mid}: missing task dialogue')
        if mid in missions:
            check(job['npc_id'] in characters and job['repeatable'] is False, f'{mid}: story ownership')
        else:
            check(job['repeatable'] is True and job['cooldown_seconds'] > 0, f'{mid}: repeat cooldown')
        choices = job.get('choices', [])
        if choices:
            unique(choices, mid + ' choices')
            check(len(choices) == 2 and len(job['steps']) == 1 and job['steps'][0]['action'] == 'talk', f'{mid}: talk-only prefix before route choice')
            signatures = [json.dumps(c['steps'], sort_keys=True, ensure_ascii=False) for c in choices]
            check(signatures[0] != signatures[1], f'{mid}: choices only change copy')
            routes = [(c['id'], job['steps'] + c['steps']) for c in choices]
        else: routes = [('default', job['steps'])]
        for route_id, steps in routes:
            label = f'{mid}/{route_id}'
            route_count += 1
            cargo = Counter(); validated_parcels = set(); parcel_seen = False
            check(bool(steps), f'{label}: no action steps')
            for step in steps:
                target = step['target']; action = step['action']; item = step['item_id']
                check(target in stations, f'{label}: unbuilt target {target}')
                used_targets.add(target)
                check(action in ['talk', 'pickup', 'verify_code', 'deliver', 'return'], f'{label}: unknown action {action}')
                check(step['required_vehicle'] in ['any', 'bicycle', 'car'], f'{label}: unknown vehicle')
                check(bool(step['caption']), f'{label}: missing caption')
                check(item == '' or item in items, f'{label}: unknown item {item}')
                if item in foods: used_foods.add(item)
                if action != 'talk': check(item in items, f'{label}: action requires item')
                if action == 'verify_code':
                    check(bool(re.fullmatch(r'\d{4}', step.get('code', ''))), f'{label}: fictional four-digit job code required')
                    check(items[item]['kind'] == 'parcel', f'{label}: code used for non-parcel')
                    validated_parcels.add(item)
                if action == 'pickup':
                    if items[item]['kind'] == 'parcel':
                        parcel_seen = True
                        check(item in validated_parcels, f'{label}: parcel pickup before code verification')
                    cargo[item] += 1
                if action in ['deliver', 'return']:
                    check(cargo[item] >= 1, f'{label}: delivery or return without matching cargo')
                    cargo[item] -= 1
            check(all(amount == 0 for amount in cargo.values()), f'{label}: cargo left without final delivery/return')
            if parcel_seen: parcel_route_count += 1
    check(len(used_foods) >= 12, 'at least 12 foods must occur in actual task routes')
    check(len(used_targets) >= 24, 'task routes do not explore enough stations')
    result = dict(status='PASS',validation_scope='Authored JSON relationships and source metadata only; runtime gameplay, device performance and source factual accuracy need separate review.',checks=CHECKS,stations=len(stations),foods=len(foods),foods_in_routes=len(used_foods),characters=len(characters),missions=len(missions),choice_missions=sum(bool(m.get('choices')) for m in missions.values()),delivery_templates=len(templates),categories=dict(categories),route_chains=route_count,parcel_route_chains=parcel_route_count,task_target_count=len(used_targets),research_sources=len(sources),research_major_themes=research['major_theme_count'],research_topic_tags=len(topics))
    return result


if __name__ == '__main__':
    try:
        result = validate()
    except (AssertionError, KeyError, TypeError, ValueError) as error:
        print(json.dumps(dict(status='FAIL',error=str(error),checks=CHECKS),ensure_ascii=False))
        sys.exit(1)
    output = ROOT / 'qa/taiwan-life-data-validation-v04.json'
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))
