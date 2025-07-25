activity = ->(time, title, content) {
  li {
    h3 {
      span time, class: 'time'
      span title, class: 'title'
    }
    description {
      emit_markdown(content)
    }
  }
}

export template {
  html5 {
    head {
      title 'La Réunion 2025'
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      # link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/style.css'
    }
    body {
      header {
        h1 'La Réunion 2025'
        h2 'Lundi 28/07/2025 - Samedi 02/08/2025'
      }
      content {
        emit_markdown <<~EOF
          Bienvenu(e)s au site de la Réunion 2025! Nous sommes très heureux de
          vous acceuillir chez nous pour cette réunion festive entre ami(e)s.
          Au cours de la semaine, chacun de vous est libre de proposer des
          activités, et on profitera aussi des soirées pour celebrer avec la
          musique, la danse, les contes autour du feu, des films etc.

          Voici un programme provisoire pour la semaine de la réunion.
          Plusieures choses pourront se passer en même temps, et on laisse la
          place à l'inspiration du moment pour ceux qui sont présents.
          
          En plus des activités indiquées ci-dessous, il y aura sans doute la
          vie quotidienne commune, et sur tout la cuisine et les repas, qui sont
          aussi une façon de se rencontrer.
          
          Si vous voulez proposer une activité, merci de nous contacter, pour
          qu'on puisse mettre les détails ici.

          À très bientôt!

          Zohar & Sharon
        EOF

        program {
          day(id: '28-07') {
            h2 'Lundi 28/07/2025'
            ul {
              emit activity, '10h-12h', 'Atelier construction bois', <<~EOF
                Conception et fabrication des structures pour la fête de
                vendredi avec Sharon, à partir des matériaux qu'on trouve sur
                place.
              EOF

              emit activity, '17h-19h', 'Aménagement jardin', <<~EOF
                Préparation du jardin pour la fete: installation d'éclairage et
                de lignes éléctriques.
              EOF
            }
          }

          day(id: '29-07') {
            h2 'Mardi 29/07/2025'
            ul {
              emit activity, '10h-12h', 'Atelier construction bois', <<~EOF
                Conception et fabrication des structures pour la fête de
                vendredi avec Sharon, à partir des matériaux qu'on trouve sur
                place.
              EOF

              emit activity, '14h30-16h', 'Atelier jardinage syntropique', <<~EOF
                Introduction à l'agroforesterie syntropique avec Sharon dans le
                jardin. Venez avec vos sécateurs!
              EOF

              emit activity, '16h-17h', 'Atelier dance en cercle', <<~EOF
                Dance folk en cercle avec Zohar.
              EOF

              emit activity, '17h-19h', 'Répétitions musicales', <<~EOF
                Rencontres musicales pour ceux qui veulent jouer/chanter dans le
                concert de vendredi soir.
              EOF

              emit activity, '20h00-22h', 'Cinema dans le jardin - Monty Python: La Vie de Brian', <<~EOF
                L'histoire incroyable de Brian Cohen, né dans une étable proche
                de celle de Jésus de Nazareth. Une comedie de Monty Python, en
                anglais avec sous-titres en français.
              EOF
            }
          }

          day(id: '30-07') {
            h2 'Mercredi 30/07/2025'
            ul {
              emit activity, '10h-12h', 'Atelier construction bois', <<~EOF
                Montage des constructions.
              EOF

              emit activity, '14h30-16h', 'Atelier jardinage syntropique', <<~EOF
                Introduction à l'agroforesterie syntropique avec Sharon dans le
                jardin. Venez avec vos sécateurs!
              EOF

              emit activity, '16h-17h', 'Atelier dance en cercle', <<~EOF
                Dance folk en cercle avec Zohar.
              EOF

              emit activity, '17h-19h', 'Répétitions musicales', <<~EOF
                Rencontres musicales pour ceux qui veulent jouer/chanter dans le
                concert de vendredi soir.
              EOF

              emit activity, '20h00-22h', 'Cinema dans le jardin: La Princesse Bouton d\'or (The Princess Bride)', <<~EOF
                Une histoire d'amour et d'aventure et de fantaisie pour petits
                et grands. Anglais avec sous-titres en français.
              EOF
            }
          }

          day(id: '31-07') {
            h2 'Jeudi 31/07/2025'
            ul {
              emit activity, '10h-12h', 'Atelier cuisine', <<~EOF
                Préparation des délices pour la fête de vendredi: quiches.
              EOF

              emit activity, '14h30-16h', 'Atelier jardinage syntropique', <<~EOF
                Introduction à l'agroforesterie syntropique avec Sharon dans le
                jardin. Venez avec vos sécateurs!
              EOF

              emit activity, '16h-17h', 'Atelier dance en cercle', <<~EOF
                Dance folk en cercle avec Zohar.
              EOF

              emit activity, '17h-19h', 'Atelier cuisine', <<~EOF
                Préparation des délices pour la fête de vendredi: falafel +
                mititei (petites boulettes de viande grillées à la Roumaine!)
              EOF

              emit activity, '20h00-22h', 'Cinema dans le jardin - Monty Python: Sacré Graal', <<~EOF
                La légende classique du Roi Arthur, sa bande de chevaliers
                gallants, et la quête du graal. Une comedie de Monty Python, en
                anglais avec sous-titres en français.
              EOF
            }
          }

          day(id: '01-08') {
            h2 'Vendredi 01/08/2025'
            p <<~EOF
              Le jour de vendredi est sans doute la culmination de la semaine.
              La fête commencera à 17h avec un apéro festif, suivi par un
              concert préparé par les musiciens (professionels ou amateurs).
              
              Après le concert, on vous propose un diner festif à libre service
              dans le jardin, ou on pourra se régaler des fruits des ateliers
              cuisine.
              
              Pour servir le diner on prevoit la construction de deux stands
              séparés pour la bouffe, plus un stand pour les boissons. On aura
              besoin des quelques bénévoles pour aider aux stands pendant la
              fête.

              Le diner sera suivi par un méga giga dance party!
            EOF
            ul {
              emit activity, '10h-12h', 'Atelier cuisine', <<~EOF
                Préparation des délices pour la fête de vendredi: falafel +
                hoummous + salades.
              EOF

              emit activity, '17h', 'Rassemblement apéritif', <<~EOF
                On arrive!
              EOF

              emit activity, '19h', 'Concert spécial', <<~EOF
                Programme ouvert.
              EOF

              emit activity, '20h', 'Diner + party!', <<~EOF
                Hyper Méga Giga.
              EOF
            }
          }

        }
      }
      footer {
        hr
      }
    }
  }
}
