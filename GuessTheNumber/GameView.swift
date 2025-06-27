//
//  GameView.swift
//  GuessTheNumber
//
//  Created by DevTipsy94 on 04/07/2023.
//

import SwiftUI

struct Score: Identifiable, Codable {
    var id = UUID()
    let position: Int
    let pseudo: String
    let timeElapsed: TimeInterval
    let numberOfAttempts: Int
    let ratio: Double
    let date: Date
    
    // Computed property pour le départage transparent
    // Plus la valeur est faible, meilleur est le classement
    var tieBreaker: Double {
        return Double(numberOfAttempts) + (timeElapsed / 60.0)
    }
    
    init(position: Int, pseudo: String, timeElapsed: TimeInterval, numberOfAttempts: Int, ratio: Double) {
        self.position = position
        self.pseudo = pseudo
        self.timeElapsed = timeElapsed
        self.numberOfAttempts = numberOfAttempts
        self.ratio = ratio
        self.date = Date()
    }
}

class GameViewModel: ObservableObject {
    @Published var secretNumber: Int
    @Published var attempts: Int
    @Published var startTime: Date
    @Published var currentPlayer: String
    @Published var scores: [Score]
    @Published var userGuess: String = ""
    @Published var gameMessage: String = "Devinez le nombre entre 0 et 100"
    @Published var showingScoreSheet = false
    @Published var isGameWon = false
    @Published var showCelebration = false
    
    private let maxScores = 10
    private let scoresKey = "SavedScores"
    
    init() {
        secretNumber = Int.random(in: 0...100)
        attempts = 0
        startTime = Date()
        currentPlayer = ""
        scores = []
        loadScores()
    }
    
    // Nouvelle fonction de calcul de score cohérent
    private func calculateScore(timeElapsed: TimeInterval, attempts: Int) -> Double {
        // Score basé sur l'efficacité : moins de temps ET moins de tentatives = meilleur score
        // Formule: Score = (1000 / tentatives) + (300 / temps_en_secondes)
        // Cela donne un score entre ~3 (minimum) et ~100 (maximum théorique)
        
        let attemptsFactor = 1000.0 / Double(attempts)
        let timeFactor = 300.0 / max(timeElapsed, 1.0) // Éviter division par 0
        let rawScore = attemptsFactor + timeFactor
        
        // Normaliser entre 1.0 (minimum) et 50.0 (maximum)
        return max(min(rawScore, 50.0), 1.0)
    }
    
    func makeGuess() {
        guard !isGameWon else { return }
        
        guard let number = Int(userGuess) else {
            gameMessage = "Veuillez entrer un nombre valide"
            return
        }
        
        attempts += 1
        
        if number < secretNumber {
            gameMessage = "Plus grand ! 📈"
        } else if number > secretNumber {
            gameMessage = "Plus petit ! 📉"
        } else {
            let endTime = Date()
            let timeElapsed = endTime.timeIntervalSince(startTime)
            let calculatedScore = calculateScore(timeElapsed: timeElapsed, attempts: attempts)
            
            let newScore = Score(
                position: 0, // Sera recalculé lors du tri
                pseudo: currentPlayer,
                timeElapsed: timeElapsed,
                numberOfAttempts: attempts,
                ratio: calculatedScore
            )
            
            addScore(newScore)
            gameMessage = "🎉 Félicitations, \(currentPlayer) !"
            isGameWon = true
            showCelebration = true
            
            // Animation avec délai pour l'expérience utilisateur
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showingScoreSheet = true
            }
        }
        
        userGuess = ""
    }
    
    private func addScore(_ newScore: Score) {
        // Ajouter le nouveau score
        scores.append(newScore)
        
        // Tri sophistiqué avec système de départage transparent
        scores.sort { first, second in
            // Si les scores sont identiques, on utilise le tieBreaker
            if first.ratio == second.ratio {
                return first.tieBreaker < second.tieBreaker // Plus petit tieBreaker = mieux classé
            }
            return first.ratio > second.ratio // Plus grand score = mieux classé
        }
        
        // Limiter à 10 scores maximum
        if scores.count > maxScores {
            scores = Array(scores.prefix(maxScores))
        }
        
        // Sauvegarder immédiatement
        saveScores()
    }
    
    private func saveScores() {
        do {
            let data = try JSONEncoder().encode(scores)
            UserDefaults.standard.set(data, forKey: scoresKey)
        } catch {
            print("Erreur lors de la sauvegarde: \(error)")
        }
    }
    
    private func loadScores() {
        guard let data = UserDefaults.standard.data(forKey: scoresKey) else { return }
        
        do {
            scores = try JSONDecoder().decode([Score].self, from: data)
        } catch {
            print("Erreur lors du chargement: \(error)")
            scores = []
        }
    }
    
    func restartGame() {
        secretNumber = Int.random(in: 0...100)
        attempts = 0
        startTime = Date()
        gameMessage = "Devinez le nombre entre 0 et 100"
        isGameWon = false
        userGuess = ""
        showCelebration = false
    }
}

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var showingPlayerNameSheet = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Arrière-plan dégradé moderne
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // En-tête avec animation
                    VStack(spacing: 16) {
                        Text(viewModel.gameMessage)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(viewModel.isGameWon ? .green : .primary)
                            .scaleEffect(viewModel.showCelebration ? 1.1 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showCelebration)
                        
                        if !viewModel.isGameWon {
                            Text("Tentatives: \(viewModel.attempts)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Zone de saisie avec style moderne
                    VStack(spacing: 20) {
                        TextField("Votre proposition", text: $viewModel.userGuess)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .focused($isTextFieldFocused)
                            .disabled(viewModel.isGameWon)
                            .opacity(viewModel.isGameWon ? 0.6 : 1.0)
                            .onSubmit {
                                viewModel.makeGuess()
                            }
                        
                        // Bouton principal avec style proéminent
                        Button {
                            viewModel.makeGuess()
                            isTextFieldFocused = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Valider")
                                    .fontWeight(.semibold)
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.isGameWon ? Color.gray : Color.blue)
                            )
                        }
                        .disabled(viewModel.userGuess.isEmpty || viewModel.isGameWon)
                        .buttonStyle(.plain)
                        .scaleEffect(viewModel.userGuess.isEmpty || viewModel.isGameWon ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.userGuess.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    // Animation de célébration
                    if viewModel.showCelebration {
                        Text("🎊 Nombre trouvé en \(viewModel.attempts) tentatives ! 🎊")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .scaleEffect(1.1)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Bouton nouvelle partie
                    if viewModel.isGameWon {
                        Button {
                            viewModel.restartGame()
                            showingPlayerNameSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Nouvelle partie")
                                    .fontWeight(.semibold)
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.5), value: viewModel.isGameWon)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showCelebration)
            }
            .navigationTitle("🎯 Devine le nombre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingScoreSheet = true
                    } label: {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingPlayerNameSheet) {
                PlayerNameView(
                    playerName: $viewModel.currentPlayer,
                    isPresented: $showingPlayerNameSheet
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.showingScoreSheet) {
                ScoreView(scores: viewModel.scores, isPresented: $viewModel.showingScoreSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if viewModel.currentPlayer.isEmpty {
                    showingPlayerNameSheet = true
                }
            }
        }
    }
}

struct PlayerNameView: View {
    @Binding var playerName: String
    @Binding var isPresented: Bool
    @State private var temporaryName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Bienvenue !")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Entrez votre pseudo pour commencer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                TextField("Votre pseudo", text: $temporaryName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        playerName = temporaryName.isEmpty ? "Joueur" : temporaryName
                        isPresented = false
                    }
                
                Button {
                    playerName = temporaryName.isEmpty ? "Joueur" : temporaryName
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Commencer")
                            .fontWeight(.semibold)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

struct ScoreView: View {
    let scores: [Score]
    @Binding var isPresented: Bool
    @State private var showingScoreInfo = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Arrière-plan dégradé
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    if scores.isEmpty {
                        // État vide avec illustration
                        VStack(spacing: 20) {
                            Image(systemName: "trophy")
                                .font(.system(size: 80))
                                .foregroundColor(.orange.opacity(0.5))
                            
                            Text("Aucun score pour le moment")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Jouez une partie pour voir vos résultats ici !")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // En-tête explicatif
                        VStack(spacing: 8) {
                            HStack {
                                Text("Top 10 des Meilleurs Scores")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Button {
                                    showingScoreInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text("Score = Efficacité (moins de tentatives + moins de temps = mieux)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        
                        List {
                            ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                                ScoreRowView(score: score, rank: index + 1)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("🏆 Tableau des scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .popover(isPresented: $showingScoreInfo, arrowEdge: .bottom) {
                ScoreInfoView()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

struct ScoreRowView: View {
    let score: Score
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    // Correction : badge cohérent, tous en version "fill"
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill" // Corrigé : était "medal" maintenant "medal.fill"
        default: return "\(rank).circle.fill"
        }
    }
    
    private var formattedTime: String {
        if score.timeElapsed < 60 {
            return String(format: "%.0fs", score.timeElapsed)
        } else {
            let minutes = Int(score.timeElapsed) / 60
            let seconds = Int(score.timeElapsed) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icône de rang
            Image(systemName: rankIcon)
                .font(.title2)
                .foregroundColor(rankColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(score.pseudo)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tentatives")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(score.numberOfAttempts)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(formattedTime)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(score.ratio.truncatingRemainder(dividingBy: 1) == 0 ?
                     String(format: "%.0f", score.ratio) :
                     String(format: "%.2f", score.ratio))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 4)
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}

// MARK: - Vue d'information corrigée avec scroll et navigation
struct ScoreInfoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête avec icône explicative
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Comment ça marche ?")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    // Explication du scoring principal
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Calcul du Score", systemImage: "function")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Le score récompense l'efficacité : moins de tentatives et moins de temps donnent un meilleur score (maximum 50 points).")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Formule explicative avec style code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Formule utilisée :")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("Score = (1000 ÷ tentatives) + (300 ÷ temps)")
                                .font(.caption)
                                .fontFamily(.monospaced)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Explication du départage
                    VStack(alignment: .leading, spacing: 12) {
                        Label("En cas d'égalité", systemImage: "scale.3d")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("Priorité donnée au nombre de tentatives, puis au temps. La stratégie prime sur la vitesse.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Section exemples pratiques
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Exemples de scores", systemImage: "star.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.yellow)
                        
                        VStack(spacing: 8) {
                            ExampleScoreRow(attempts: 1, time: "3s", score: "50.0", description: "Score parfait")
                            ExampleScoreRow(attempts: 2, time: "10s", score: "30.0", description: "Excellent")
                            ExampleScoreRow(attempts: 5, time: "30s", score: "10.0", description: "Bon")
                            ExampleScoreRow(attempts: 10, time: "60s", score: "5.0", description: "Correct")
                        }
                    }
                    
                    // Astuce gameplay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("Stratégie gagnante")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("Utilisez la recherche binaire ! Commencez par 50, puis 25 ou 75 selon la réponse, et ainsi de suite. Vous trouverez n'importe quel nombre en maximum 7 tentatives.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .navigationTitle("Système de Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        // Cette action sera gérée par le parent
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Composant exemple de score
struct ExampleScoreRow: View {
    let attempts: Int
    let time: String
    let score: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(attempts) tentatives • \(time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(score)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}
