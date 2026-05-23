"""生成 code2offer ER 图"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import os, numpy as np

OUT = os.path.join(os.path.dirname(__file__), "er_diagram.png")
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

fig, ax = plt.subplots(figsize=(20, 14))
ax.set_xlim(0, 20); ax.set_ylim(0, 14)
ax.axis('off'); ax.set_facecolor('#FAFBFC')

def entity(ax, x, y, w, h, title, attrs, color='#E8F0FE', border='#1A73E8'):
    r = FancyBboxPatch((x-w/2, y-h/2), w, h, boxstyle="round,pad=0.1",
                       facecolor=color, edgecolor=border, linewidth=2, zorder=3)
    ax.add_patch(r)
    ax.plot([x-w/2, x+w/2], [y+h/2-0.45, y+h/2-0.45], color=border, linewidth=1, zorder=4)
    ax.text(x, y+h/2-0.22, title, ha='center', va='center', fontsize=9.5, fontweight='bold', color=border, zorder=5)
    for i, (attr, pk) in enumerate(attrs):
        pfx = '• ' if pk else '  '
        c = '#1a1a1a' if pk else '#555'
        ax.text(x-w/2+0.25, y+h/2-0.8-i*0.33, f'{pfx}{attr}',
                fontsize=7.2, color=c, fontweight='bold' if pk else 'normal',
                fontfamily='monospace', zorder=5)

def conn(ax, x1, y1, x2, y2, label=''):
    ax.plot([x1, x2], [y1, y2], color='#999', linewidth=1.3, zorder=1)
    dx, dy = x2-x1, y2-y1; L = np.sqrt(dx**2+dy**2) or 1
    nx, ny = -dy/L*0.35, dx/L*0.35
    mx, my = (x1+x2)/2+nx, (y1+y2)/2+ny
    ax.text(mx, my, label, fontsize=7.5, color='#E37400', fontweight='bold',
            bbox=dict(fc='white', ec='none', alpha=0.85, pad=1), zorder=6)

# ── entities ──
entity(ax, 3, 11.5, 3.6, 2.6, 'users',
    [('id (UUID)',1),('username',0),('email',0),('password_hash',0),('created_at',0),('updated_at',0)])
entity(ax, 10, 11.5, 4.4, 3.8, 'problems',
    [('id (UUID)',1),('title',0),('difficulty',0),('description_cn',0),
     ('solution_approach',0),('solution_code',0),('complexity_time',0),
     ('* embedding',0),('created_at',0),('updated_at',0)])
entity(ax, 17, 11.5, 2.6, 1.6, 'tags', [('id (SERIAL)',1),('name',0),('description',0)])
entity(ax, 10, 6.0, 5.0, 3.8, 'analysis_history',
    [('id (UUID)',1),('user_id (FK)',0),('problem_id (FK)',0),('user_input',0),
     ('asr_text',0),('ai_feedback',0),('overall_score',0),('match_similarity',0),
     ('created_at',0)], color='#E8F5E9', border='#2E7D32')
entity(ax, 3, 3.5, 4.0, 2.4, 'evaluation_details',
    [('id (SERIAL)',1),('history_id (FK)',0),('criteria_id (FK)',0),
     ('score',0),('comment',0),('suggestion',0)], color='#FCE4EC', border='#C62828')
entity(ax, 10, 2.5, 3.8, 2.0, 'evaluation_criteria',
    [('id (SERIAL)',1),('name',0),('name_en',0),('weight',0),('max_score',0),('sort_order',0)],
    color='#F3E5F5', border='#7B1FA2')
# M:N junction
r = FancyBboxPatch((14.5, 8.9), 3.0, 1.1, boxstyle="round,pad=0.06",
                   facecolor='#FFF3E0', edgecolor='#E37400', linewidth=1.5, linestyle='--', zorder=3)
ax.add_patch(r)
ax.text(16, 9.45, 'problem_tags', ha='center', va='center', fontsize=8.5, fontweight='bold', color='#E37400', zorder=5)
ax.text(16, 9.05, '• problem_id\n• tag_id', ha='center', va='center', fontsize=6.8, color='#555', fontfamily='monospace', zorder=5)

# ── connections ──
conn(ax, 3, 10.2, 7.5, 7.9, '1:N')
conn(ax, 10, 9.6, 10, 7.9, '1:N')
conn(ax, 12.2, 10.5, 14.5, 9.45, '1:N')
conn(ax, 17, 10.7, 16, 9.45, '1:N')
conn(ax, 7.5, 5.0, 5.0, 4.7, '1:N')
conn(ax, 8.1, 2.5, 5.0, 3.5, '1:N')

# legend
lp = [(mpatches.Patch(fc='#E8F0FE', ec='#1A73E8'),'Entity'),
      (mpatches.Patch(fc='#E8F5E9', ec='#2E7D32'),'Transaction'),
      (mpatches.Patch(fc='#FCE4EC', ec='#C62828'),'Dependent'),
      (mpatches.Patch(fc='#F3E5F5', ec='#7B1FA2'),'Config'),
      (mpatches.Patch(fc='#FFF3E0', ec='#E37400'),'M:N Junction')]
ax.legend([p[0] for p in lp], [p[1] for p in lp], loc='lower right', fontsize=7.5,
          framealpha=0.9, edgecolor='#ddd', title='Legend', title_fontsize=8)

ax.text(10, 13.2, 'code2offer Database ER Diagram', ha='center', va='center',
        fontsize=15, fontweight='bold', color='#1a1a1a')
ax.text(10, 12.6, 'PostgreSQL 16 + pgvector | 7 Tables | 6 Entities + 1 M:N Junction',
        ha='center', va='center', fontsize=8.5, color='#888')

plt.tight_layout(pad=1)
plt.savefig(OUT, dpi=180, bbox_inches='tight', facecolor='white', edgecolor='none')
plt.close()
print(f'ER saved: {OUT} ({os.path.getsize(OUT)/1024:.0f} KB)')
