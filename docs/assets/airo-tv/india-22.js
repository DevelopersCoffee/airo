export function startIndiaMotion(root, media = window.matchMedia('(prefers-reduced-motion: reduce)')) {
  const stage = root.querySelector('[data-india-multiview]');
  const cards = [...root.querySelectorAll('.cw-card')];
  if (!stage) return;
  if (media.matches) {
    stage.dataset.panes = '4';
    return;
  }
  const sequence = ['1', '2', '4'];
  let index = 0;
  stage.dataset.panes = sequence[0];
  if (cards.length) {
    cards[0].classList.add('is-selected');
  }
  window.setInterval(() => {
    index = (index + 1) % sequence.length;
    stage.dataset.panes = sequence[index];
    if (cards.length) {
      cards.forEach((card, cardIndex) => {
        card.classList.toggle('is-selected', cardIndex === index % cards.length);
      });
    }
  }, 2400);
}
