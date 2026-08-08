// functions/test/maskPhone.test.js
// _maskPhone masque un numéro de téléphone pour les logs/emails de reçu —
// ne doit jamais exposer le numéro complet, garde les 2 derniers chiffres
// pour que le client puisse s'y reconnaître.
let index;
beforeAll(() => {
  index = require("../index.js");
});

describe("_maskPhone", () => {
  test("numéro complet → masqué sauf les 2 derniers chiffres", () => {
    expect(index._maskPhone("0197001122")).toBe("********22");
  });

  test("numéro international → même comportement", () => {
    expect(index._maskPhone("22997001122")).toBe("*********22");
  });

  test("numéro très court (<=2 chiffres) → entièrement masqué", () => {
    expect(index._maskPhone("12")).toBe("**");
    expect(index._maskPhone("1")).toBe("**");
  });

  test("null/undefined → ne plante pas, retourne masqué", () => {
    expect(index._maskPhone(null)).toBe("**");
    expect(index._maskPhone(undefined)).toBe("**");
  });
});
