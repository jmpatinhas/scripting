using ExampleProcess.ObjectRepository;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text.RegularExpressions;
using UiPath.CodedWorkflows;
using UiPath.Core;
using UiPath.Core.Activities.Storage;
using UiPath.Orchestrator.Client.Models;
using UiPath.UIAutomationNext.API.Contracts;
using UiPath.UIAutomationNext.API.Models;
using UiPath.UIAutomationNext.Enums;

namespace ExampleProcess
{
    public class companyNameMatcher : CodedWorkflow
    {
        
        // Private fields for the matcher
        private HashSet<string> exclusionWords;
        
        [Workflow]
        public bool Execute(string companyName1, string companyName2, DataTable wordExclusions, bool matchResult)
        {
            try
            {
                // Get input values
                // string companyName1;
                // string companyName2;
                // DataTable wordExclusions;
                double threshold = 0.85;
                
                // Load exclusion words
                LoadExclusionWords(wordExclusions);
                
                // Perform the comparison
                matchResult = CompareCompanyNames(companyName1, companyName2, threshold);
                
                return matchResult;
                // Optional: Log the result for debugging
                Log($"Company name comparison: '{companyName1}' vs '{companyName2}' = {matchResult}");
            }
            catch (Exception ex)
            {
                Log($"Error in company name matching: {ex.Message}");
                throw;
            }
        }
        
        private void LoadExclusionWords(DataTable dtWordExclusions)
        {
            exclusionWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            
            if (dtWordExclusions != null)
            {
                // Assuming the DataTable has a column with exclusion words
                // You may need to adjust the column index/name based on your table structure
                foreach (DataRow row in dtWordExclusions.Rows)
                {
                    var word = row[0]?.ToString()?.Trim();
                    if (!string.IsNullOrEmpty(word))
                    {
                        exclusionWords.Add(word);
                    }
                }
            }
            
            // Add common variations if not already present
            var commonExclusions = new[] { "inc", "incorporated", "corp", "corporation", "co", "company", 
                                         "ltd", "limited", "llc", "lp", "llp", "plc", "sa", "gmbh", 
                                         "ag", "bv", "nv", "spa", "srl", "kg", "oy", "ab", "as", 
                                         "the", "&", "and" };
            
            foreach (var word in commonExclusions)
            {
                exclusionWords.Add(word);
            }
        }
        
        private bool CompareCompanyNames(string companyName1, string companyName2, double threshold)
        {
            if (string.IsNullOrWhiteSpace(companyName1) || string.IsNullOrWhiteSpace(companyName2))
                return false;
            
            // Step 1: Exact match (case insensitive)
            if (string.Equals(companyName1, companyName2, StringComparison.OrdinalIgnoreCase))
                return true;
            
            // Step 2: Normalize both names
            string normalized1 = NormalizeName(companyName1);
            string normalized2 = NormalizeName(companyName2);
            
            Log($"Normalized names: '{normalized1}' vs '{normalized2}'");
            
            // Step 3: Check normalized exact match
            if (string.Equals(normalized1, normalized2, StringComparison.OrdinalIgnoreCase))
                return true;
            
            // Step 4: Check if one is contained in the other (after normalization)
            if (IsSubstringMatch(normalized1, normalized2))
                return true;
            
            // Step 5: Use fuzzy matching algorithms
            double similarity = CalculateSimilarity(normalized1, normalized2);
            
            Log($"Similarity score: {similarity:F3}");
            
            return similarity >= threshold;
        }
        
        private string NormalizeName(string companyName)
        {
            if (string.IsNullOrWhiteSpace(companyName))
                return string.Empty;
            
            // Handle multiple company names separated by semicolons, commas, or "/"
            string primaryName = ExtractPrimaryCompanyName(companyName);
            
            // Convert to lowercase
            string normalized = primaryName.ToLowerInvariant();
            
            // Handle possessives (remove 's)
            normalized = Regex.Replace(normalized, @"'s\b", "s");
            normalized = Regex.Replace(normalized, @"'\b", "");
            
            // Remove special characters and extra spaces
            normalized = Regex.Replace(normalized, @"[^\w\s]", " ");
            normalized = Regex.Replace(normalized, @"\s+", " ");
            
            // Split into words and filter out exclusions
            var words = normalized.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                 .Where(word => !exclusionWords.Contains(word) && word.Length > 1)
                                 .ToList();
            
            // Remove duplicates while preserving order
            words = words.Distinct().ToList();
            
            // Handle common abbreviations
            words = ExpandAbbreviations(words);
            
            return string.Join(" ", words).Trim();
        }
        
        private string ExtractPrimaryCompanyName(string companyName)
        {
            var separators = new[] { ";", ",", " / ", " or ", " & ", " and " };
            
            foreach (var separator in separators)
            {
                if (companyName.Contains(separator))
                {
                    var parts = companyName.Split(new[] { separator }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length > 0)
                    {
                        return parts.OrderBy(p => p.Trim().Length).First().Trim();
                    }
                }
            }
            
            return companyName.Trim();
        }
        
        private List<string> ExpandAbbreviations(List<string> words)
        {
            var abbreviations = new Dictionary<string, string>
            {
                {"corp", "corporation"},
                {"inc", "incorporated"},
                {"co", "company"},
                {"ltd", "limited"},
                {"intl", "international"},
                {"natl", "national"},
                {"tech", "technology"},
                {"sys", "systems"},
                {"sol", "solutions"},
                {"svc", "services"},
                {"grp", "group"}
            };
            
            return words.Select(word => abbreviations.ContainsKey(word) ? abbreviations[word] : word).ToList();
        }
        
        private bool IsSubstringMatch(string name1, string name2)
        {
            if (string.IsNullOrEmpty(name1) || string.IsNullOrEmpty(name2))
                return false;
            
            return name1.Contains(name2) || name2.Contains(name1);
        }
        
        private double CalculateSimilarity(string name1, string name2)
        {
            if (string.IsNullOrEmpty(name1) || string.IsNullOrEmpty(name2))
                return 0.0;
            
            double jaroWinkler = JaroWinklerSimilarity(name1, name2);
            double levenshtein = LevenshteinSimilarity(name1, name2);
            double tokenSort = TokenSortSimilarity(name1, name2);
            
            return Math.Max(Math.Max(jaroWinkler, levenshtein), tokenSort);
        }
        
        private double JaroWinklerSimilarity(string s1, string s2)
        {
            if (s1 == s2) return 1.0;
            
            int len1 = s1.Length;
            int len2 = s2.Length;
            
            if (len1 == 0 || len2 == 0) return 0.0;
            
            int matchWindow = Math.Max(len1, len2) / 2 - 1;
            if (matchWindow < 0) matchWindow = 0;
            
            bool[] s1Matches = new bool[len1];
            bool[] s2Matches = new bool[len2];
            
            int matches = 0;
            int transpositions = 0;
            
            // Find matches
            for (int i = 0; i < len1; i++)
            {
                int start = Math.Max(0, i - matchWindow);
                int end = Math.Min(i + matchWindow + 1, len2);
                
                for (int j = start; j < end; j++)
                {
                    if (s2Matches[j] || s1[i] != s2[j]) continue;
                    s1Matches[i] = true;
                    s2Matches[j] = true;
                    matches++;
                    break;
                }
            }
            
            if (matches == 0) return 0.0;
            
            // Find transpositions
            int k = 0;
            for (int i = 0; i < len1; i++)
            {
                if (!s1Matches[i]) continue;
                while (!s2Matches[k]) k++;
                if (s1[i] != s2[k]) transpositions++;
                k++;
            }
            
            double jaro = (matches / (double)len1 + matches / (double)len2 + 
                          (matches - transpositions / 2.0) / matches) / 3.0;
            
            // Calculate Jaro-Winkler
            int prefixLength = 0;
            for (int i = 0; i < Math.Min(len1, len2) && i < 4; i++)
            {
                if (s1[i] == s2[i]) prefixLength++;
                else break;
            }
            
            return jaro + (0.1 * prefixLength * (1.0 - jaro));
        }
        
        private double LevenshteinSimilarity(string s1, string s2)
        {
            int len1 = s1.Length;
            int len2 = s2.Length;
            
            if (len1 == 0) return len2 == 0 ? 1.0 : 0.0;
            if (len2 == 0) return 0.0;
            
            int[,] d = new int[len1 + 1, len2 + 1];
            
            for (int i = 0; i <= len1; i++) d[i, 0] = i;
            for (int j = 0; j <= len2; j++) d[0, j] = j;
            
            for (int i = 1; i <= len1; i++)
            {
                for (int j = 1; j <= len2; j++)
                {
                    int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
                    d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + cost);
                }
            }
            
            int maxLen = Math.Max(len1, len2);
            return 1.0 - (double)d[len1, len2] / maxLen;
        }
        
        private double TokenSortSimilarity(string s1, string s2)
        {
            var tokens1 = s1.Split(' ', StringSplitOptions.RemoveEmptyEntries).OrderBy(x => x);
            var tokens2 = s2.Split(' ', StringSplitOptions.RemoveEmptyEntries).OrderBy(x => x);
            
            string sorted1 = string.Join(" ", tokens1);
            string sorted2 = string.Join(" ", tokens2);
            
            return LevenshteinSimilarity(sorted1, sorted2);
        }
        
        private void Log(string message)
        {
            // Use UiPath's logging - this will appear in the execution logs
            Console.WriteLine($"[CompanyNameMatcher] {message}");
        }
    }
}