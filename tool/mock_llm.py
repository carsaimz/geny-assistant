#!/usr/bin/env python3
"""Mock OpenAI-compatible LLM server for PrivateAgent end-to-end testing.

Plays a deterministic UI agent: it inspects the CURRENT SCREEN dump inside
the user message and returns the next scripted JSON action for the scenario
"open YouTube and search lofi music" (open app -> tap Search -> type ->
enter -> done).

Usage:
    python3 tool/mock_llm.py            # listens on 127.0.0.1:8787
    adb reverse tcp:8787 tcp:8787       # let the device reach it via USB
Then in the app: Settings -> Custom provider -> Base URL http://127.0.0.1:8787/v1
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = '/tmp/mock_llm_requests.log'


def decide(screen: str) -> dict:
    # State machine keyed off dump features, ordered from goal-completion
    # backwards so transient label changes (e.g. the EditText swapping its
    # "Search YouTube" hint for the typed value) cannot derail the script.
    s = screen.lower()
    # PrivateAgent's own UI also contains the goal text ("...lofi music")
    # and its running-task controls — never confuse it with results.
    on_private_agent = ('privateagent' in s or 'describe a task' in s
                        or '"pause"' in s or '"cancel task"' in s)
    if on_private_agent:
        return {'action': 'open_app', 'params': {'app': 'YouTube'},
                'reasoning': 'Leaving the agent app; opening YouTube',
                'is_complete': False}
    # Inspect only the editable nodes themselves: a suggestion/history row
    # may contain "lofi" while the EditText is still empty — that must not
    # count as "typed".
    lines = s.split('\n')
    editable_lines = [l for l in lines if 'editable' in l or 'edittext' in l]
    has_editable = bool(editable_lines)
    typed_query = any('lofi' in l for l in editable_lines)
    results_visible = 'lofi' in s and not has_editable
    on_youtube_home = 'subscriptions' in s or 'shorts' in s

    if results_visible:
        return {'action': 'done', 'params': {},
                'reasoning': 'Search results for lofi are on screen',
                'is_complete': True}
    if typed_query:
        return {'action': 'press_enter', 'params': {},
                'reasoning': 'Submitting the search', 'is_complete': False}
    if has_editable:
        return {'action': 'type_text', 'params': {'text': 'lofi music'},
                'reasoning': 'Typing the search query', 'is_complete': False}
    if on_youtube_home:
        return {'action': 'click_text', 'params': {'text': 'Search'},
                'reasoning': 'Tapping the YouTube search button',
                'is_complete': False}
    if 'search youtube' in s:
        # Search screen without an editable flag in the dump: tap it first.
        return {'action': 'click_text', 'params': {'text': 'Search YouTube'},
                'reasoning': 'Focusing the YouTube search field',
                'is_complete': False}
    return {'action': 'open_app', 'params': {'app': 'YouTube'},
            'reasoning': 'Opening YouTube app first', 'is_complete': False}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode('utf-8', 'replace')
        with open(LOG, 'a') as f:
            f.write('=== REQUEST ===\n' + body[:6000] + '\n')
        try:
            payload = json.loads(body)
            user_msg = next(
                (m['content'] for m in reversed(payload.get('messages', []))
                 if m.get('role') == 'user'), '')
            screen = user_msg.split('CURRENT SCREEN:')[-1]
            action = decide(screen)
        except Exception as e:  # noqa
            action = {'action': 'wait', 'params': {'ms': 1000},
                      'reasoning': f'mock fallback: {e}', 'is_complete': False}

        resp = {
            'id': 'chatcmpl-mock',
            'object': 'chat.completion',
            'choices': [{
                'index': 0,
                'message': {'role': 'assistant',
                            'content': json.dumps(action)},
                'finish_reason': 'stop',
            }],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 10,
                      'total_tokens': 20},
        }
        data = json.dumps(resp).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        with open(LOG, 'a') as f:
            f.write('>>> replied: ' + json.dumps(action) + '\n')

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    open(LOG, 'w').close()
    print('mock LLM listening on 127.0.0.1:8787')
    HTTPServer(('127.0.0.1', 8787), Handler).serve_forever()
