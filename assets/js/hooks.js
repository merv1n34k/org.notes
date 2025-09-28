import Typed from "typed.js";

const Typewriter = {
  mounted() {
    this.typed = new Typed(this.el, {
      strings: ["simple", "clear", "fast"],
      typeSpeed: 100,
      backSpeed: 50,
      loop: true,
    });
  },
  destroyed() {
    this.typed.destroy();
  }
};

export default Hooks = {
  Typewriter: Typewriter,
};
