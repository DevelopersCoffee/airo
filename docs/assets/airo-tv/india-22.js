export function startIndiaMotion(
  root,
  media = window.matchMedia('(prefers-reduced-motion: reduce)'),
  scheduleInterval = (fn, ms) => window.setInterval(fn, ms),
) {
  const stage = root.querySelector('[data-india-multiview]');
  const cards = [...root.querySelectorAll('.cw-card')];
  if (!stage) return;
  if (media.matches) {
    stage.dataset.panes = '4';
    return;
  }
  const sequence = ['1', '2', '4'];
  let paneIndex = 0;
  let cardIndex = 0;
  stage.dataset.panes = sequence[paneIndex];
  if (cards.length) {
    cards[0].classList.add('is-selected');
  }
  scheduleInterval(() => {
    paneIndex = (paneIndex + 1) % sequence.length;
    stage.dataset.panes = sequence[paneIndex];
    if (cards.length) {
      cardIndex = (cardIndex + 1) % cards.length;
      cards.forEach((card, i) => {
        card.classList.toggle('is-selected', i === cardIndex);
      });
    }
  }, 2400);
}
