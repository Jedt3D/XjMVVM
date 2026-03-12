/* ═══════════════════════════════════════════════════════════
   docs.js — XjMVVM Developer Guide interactive behaviour
   ═══════════════════════════════════════════════════════════ */

/* ── Theme toggle ───────────────────────────────────────── */
// Theme init runs inline in <head> (see page.html) to prevent FOUC.
// This function is called by the toggle button.
function toggleTheme() {
  var root = document.documentElement;
  var next = (root.getAttribute('data-theme') === 'dark') ? 'light' : 'dark';
  root.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
}

/* ── Sidebar mobile toggle ──────────────────────────────── */
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  sidebar.classList.toggle('open');
}

document.addEventListener('click', function (e) {
  const sidebar = document.getElementById('sidebar');
  const toggle  = document.querySelector('.sidebar-toggle');
  if (
    sidebar &&
    sidebar.classList.contains('open') &&
    !sidebar.contains(e.target) &&
    toggle && !toggle.contains(e.target)
  ) {
    sidebar.classList.remove('open');
  }
});

/* ── Diagram tab switcher ───────────────────────────────── */
// nomnoml diagrams are rendered to SVG at build time — no client-side work needed.
function switchDiagram(uid, panel, btn) {
  const root = document.getElementById(uid);
  if (!root) return;

  root.querySelectorAll('.diagram-panel').forEach(p => { p.style.display = 'none'; });
  root.querySelectorAll('.diagram-tab').forEach(b => b.classList.remove('active'));

  const target = root.querySelector('.diagram-' + panel);
  if (target) target.style.display = '';
  btn.classList.add('active');
}

// On load: hide ASCII panels (Diagram is default)
document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('.diagram-ascii').forEach(p => { p.style.display = 'none'; });
});

/* ── Active TOC link on scroll ──────────────────────────── */
(function () {
  const tocLinks = Array.from(document.querySelectorAll('.toc-link'));
  if (!tocLinks.length) return;

  const headings = tocLinks
    .map(link => document.getElementById(link.getAttribute('href').slice(1)))
    .filter(Boolean);

  let lastActive = null;

  function onScroll() {
    const scrollY  = window.scrollY + 80;
    let active = null;
    for (const h of headings) {
      if (h.offsetTop <= scrollY) active = h;
    }
    if (active === lastActive) return;
    lastActive = active;
    tocLinks.forEach(l => l.classList.remove('active'));
    if (active) {
      const link = tocLinks.find(l => l.getAttribute('href') === '#' + active.id);
      if (link) link.classList.add('active');
    }
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
})();

/* ── Code block language labels ─────────────────────────── */
(function () {
  document.querySelectorAll('.highlight').forEach(block => {
    const code    = block.querySelector('code');
    const classes = Array.from(block.classList)
      .concat(code ? Array.from(code.classList) : []);
    for (const cls of classes) {
      const match = cls.match(/^language-(\w+)$/);
      if (match) { block.setAttribute('data-lang', match[1]); break; }
    }
  });
})();

/* ── Smooth scroll for anchor links ─────────────────────── */
document.querySelectorAll('a[href^="#"]').forEach(link => {
  link.addEventListener('click', function (e) {
    const target = document.getElementById(this.getAttribute('href').slice(1));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});
